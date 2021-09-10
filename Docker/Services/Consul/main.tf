terraform {
  required_providers {
    consul = {
      source = "hashicorp/consul"
      version = "2.12.0"
    }

    docker = {
      source = "kreuzwerker/docker"
      version = "2.15.0"
    }

    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }

    time = {
      source = "hashicorp/time"
      version = "0.7.2"
    }
  }
}

data "docker_network" "meshSpineNet" {
  name = "meshSpineNet"
}

resource "random_uuid" "MasterToken" {
}

resource "random_uuid" "DefaultToken" {
}

resource "random_uuid" "AgentToken" {
}

resource "random_uuid" "AgentMasterToken" {
}

resource "random_uuid" "ReplicationToken" {
}

#
# Docs: https://www.consul.io/docs/agent/options#acl_tokens
#
locals {
  TOKENS = {
    #
    # Docs: https://www.consul.io/docs/agent/options#acl_tokens_master
    #
    MASTER_TOKEN = random_uuid.MasterToken.result

    #
    # Docs: https://www.consul.io/docs/agent/options#acl_tokens_default
    # 
    DEFAULT_TOKEN = random_uuid.DefaultToken.result

    #
    # Docs: https://www.consul.io/docs/agent/options#acl_tokens_agent
    #  
    AGENT_TOKEN = random_uuid.AgentToken.result

    #
    # Docs: https://www.consul.io/docs/agent/options#acl_tokens_agent_master
    #
    AGENT_MASTER_TOKEN = random_uuid.AgentMasterToken.result

    #
    # Docs: https://www.consul.io/docs/agent/options#acl_tokens_replication
    #
    REPLICATION_TOKEN = random_uuid.ReplicationToken.result
  }
}

# data "docker_network" "hashicorpSpineNet" {
#   name = "hashicorpSpineNet"
# }

#
# Docker Configs
# 

resource "docker_config" "ConsulConfig" {
  name = "newconsul-config-${replace(timestamp(), ":", ".")}"

  data = base64encode(
    templatefile("${path.module}/Configs/Consul/config.json",
      {
        SECRET_KEY = var.Secret

        TOKENS = local.TOKENS
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_config" "ConsulEntryScriptConfig" {
  name = "newconsul-entryconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/Consul/start.sh"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}


locals {
  CONSUL_NODES = tomap({
    Consul1 = {
      name = "Consul1"
      peers = ["Consul2", "Consul3"]
      bucket = "consul1-data"
    },
    Consul2 = {
      name = "Consul2"
      peers = ["Consul1", "Consul3"]
      bucket = "consul2-data"
    },
    Consul3 = {
      name = "Consul3"
      peers = ["Consul1", "Consul2"]
      bucket = "consul3-data"
    },
  })
}

resource "docker_service" "ConsulAgent" {
  name = "ConsulAgent"

  task_spec {
    container_spec {
      image = "consul:${var.Version}"

      command = ["/entry.sh"]

      #
      # TODO: Tweak this, Caddy, Prometheus, Loki, etc
      #
      # labels {
      #   label = "foo.bar"
      #   value = "baz"
      # }

      hostname = "ConsulAgent{{.Task.Slot}}"

      env = {
        CONSUL_BIND_INTERFACE = "eth1"
        CONSUL_CLIENT_INTERFACE = "eth1"
        CONSUL_HOST = "ConsulAgent{{.Task.Slot}}"
        NODE_HOST = "{{.Node.Hostname}}.vps1.kristianjones.dev"
      }

      # dir    = "/root"
      #user   = "1000"
      # groups = ["docker", "foogroup"]

      # privileges {
      #   se_linux_context {
      #     disable = true
      #     user    = "user-label"
      #     role    = "role-label"
      #     type    = "type-label"
      #     level   = "level-label"
      #   }
      # }

      # read_only = true

      configs {
        config_id   = docker_config.ConsulEntryScriptConfig.id
        config_name = docker_config.ConsulEntryScriptConfig.name

        file_name   = "/entry.sh"
        file_uid = "1000"
        file_mode = 7777
      }

      mounts {
        target    = "/etc/timezone"
        source    = "/etc/timezone"
        type      = "bind"
        read_only = true
      }

      mounts {
        target    = "/etc/localtime"
        source    = "/etc/localtime"
        type      = "bind"
        read_only = true
      }

      mounts {
        target    = "/Data"
        source    = "consul{{.Task.Slot}}-data"
        type      = "volume"

        volume_options {
          driver_name = "s3core-storage"
        }
      }

      #
      # Docker Configs
      # 

      #
      # Consul Configuration
      #
      configs {
        config_id   = docker_config.ConsulConfig.id
        config_name = docker_config.ConsulConfig.name

        file_name   = "/Config/Config.json"
      }

      # hosts {
      #   host = "testhost"
      #   ip   = "10.0.1.0"
      # }


      # dns_config {
      #   nameservers = ["1.1.1.1", "1.0.0.1"]
      #   search      = ["kristianjones.dev"]
      #   options     = ["timeout:3"]
      # }

      #
      # Stolon Database Secrets
      #
      # healthcheck {
      #   test     = ["CMD", "curl", "-f", "http://localhost:8080/health"]
      #   interval = "5s"
      #   timeout  = "2s"
      #   retries  = 4
      # }
    }

    runtime      = "container"
    networks     = [data.docker_network.meshSpineNet.id]

    log_driver {
      name = "loki"

      options = {
        loki-url = "https://loki.kristianjones.dev:443/loki/api/v1/push"
      }
    }
  }

  mode {
    replicated {
      replicas = 3
    }
  }

  #
  # TODO: Finetune this
  # 
  update_config {
    parallelism       = 2
    delay             = "0s"
    failure_action    = "pause"
    monitor           = "0s"
    max_failure_ratio = "0.8"
    order             = "stop-first"
  }

  # rollback_config {
  #   parallelism       = 1
  #   delay             = "5ms"
  #   failure_action    = "pause"
  #   monitor           = "10h"
  #   max_failure_ratio = "0.9"
  #   order             = "stop-first"
  # }

  endpoint_spec {
    ports {
      name           = "http"
      protocol       = "tcp"
      target_port    = "9500"
      published_port = "9500"
      publish_mode   = "host"
    }

    ports {
      name           = "grpc"
      protocol       = "tcp"
      target_port    = "9502"
      published_port = "9502"
      publish_mode   = "host"
    }

    ports {
      name           = "consul-server"
      protocol       = "tcp"
      target_port    = "9300"
      published_port = "9300"
      publish_mode   = "host"
    }
  }
}



provider "consul" {
  address    = "vps1-raw.kristianjones.dev:8500"
  datacenter = "dc1"

  token = local.TOKENS.MASTER_TOKEN
}

#
# Applications
#

#
# Hashicorp Vault
#

#
# CoreVault
#

resource "random_uuid" "CoreVaultToken" { }


resource "consul_acl_policy" "CoreVaultACL" {
  name  = "CoreVault"

  rules = file("${path.module}/Consul/CoreVault.hcl")
}

resource "consul_acl_token" "CoreVaultToken" {
  accessor_id = random_uuid.CoreVaultToken.result

  description = "Hashicorp Vault CoreVault Token"

  policies = ["${consul_acl_policy.CoreVaultACL.name}"]
  local = true
}

data "consul_acl_token_secret_id" "CoreVaultToken" {
  accessor_id = consul_acl_token.CoreVaultToken.id
}

#
# Hashicorp Vault
#

resource "random_uuid" "VaultToken" { }


resource "consul_acl_policy" "VaultACL" {
  name  = "Vault"

  rules = file("${path.module}/Consul/Vault.hcl")
}

resource "consul_acl_token" "VaultToken" {
  accessor_id = random_uuid.VaultToken.result

  description = "Hashicorp Vault Token"

  policies = ["${consul_acl_policy.VaultACL.name}"]
  local = true
}

data "consul_acl_token_secret_id" "VaultToken" {
  accessor_id = consul_acl_token.VaultToken.id
}

#
# Grafana Loki
#

resource "random_uuid" "LokiToken" { }


resource "consul_acl_policy" "LokiACL" {
  name  = "GrafanaLoki"

  rules = file("${path.module}/Consul/Loki.hcl")
}

resource "consul_acl_token" "LokiToken" {
  accessor_id = random_uuid.LokiToken.result

  description = "Grafana Loki Token"

  policies = ["${consul_acl_policy.LokiACL.name}"]
  local = true
}

data "consul_acl_token_secret_id" "LokiToken" {
  accessor_id = consul_acl_token.LokiToken.id
}

#
# Grafana Cortex
#

resource "random_uuid" "CortexToken" { }


resource "consul_acl_policy" "CortexACL" {
  name  = "GrafanaCortex"

  rules = file("${path.module}/Consul/Cortex.hcl")
}

resource "consul_acl_token" "CortexToken" {
  accessor_id = random_uuid.CortexToken.result

  description = "Grafana Cortex Token"

  policies = ["${consul_acl_policy.CortexACL.name}"]
  local = true
}

data "consul_acl_token_secret_id" "CortexToken" {
  accessor_id = consul_acl_token.CortexToken.id
}

#
# Grafana Token
#

resource "random_uuid" "GrafanaToken" { }


resource "consul_acl_policy" "GrafanaACL" {
  name  = "Grafana"

  rules = file("${path.module}/Consul/Grafana.hcl")
}

resource "consul_acl_token" "GrafanaToken" {
  accessor_id = random_uuid.GrafanaToken.result

  description = "Grafana Token"

  policies = ["${consul_acl_policy.GrafanaACL.name}"]
  local = true
}

data "consul_acl_token_secret_id" "GrafanaToken" {
  accessor_id = consul_acl_token.GrafanaToken.id
}


#
# Config Entries
#

resource "consul_config_entry" "ProxyDefaults" {
  kind = "proxy-defaults"
  # Note that only "global" is currently supported for proxy-defaults and that
  # Consul will override this attribute if you set it to anything else.
  name = "global"

  config_json = jsonencode({
    Config = {
      local_connect_timeout_ms = 1000
      handshake_timeout_ms     = 10000

      envoy_prometheus_bind_addr = "0.0.0.0:9100"

      envoy_dns_discovery_type = "LOGICAL_DNS"
    }
  })
}

# resource "consul_config_entry" "web" {
#   name = "web"
#   kind = "service-defaults"

#   config_json = jsonencode({
#     Protocol    = "http"
#   })
# }

# resource "consul_service" "Grafana" {
#   name    = "GrafanaInterface"
#   node    = "${consul_node.Grafana.name}"
#   port    = 8080
#   tags    = ["tag0"]
# }

# resource "consul_config_entry" "Grafana" {
#   name = "${consul_service.Grafana.name}"
#   kind = "service-defaults"

#   config_json = jsonencode({
#     Protocol    = "http"
#   })
# }


# resource "consul_node" "Grafana" {
#   name    = "GrafanaService"
#   address = "tasks.Grafana"

#   meta = {
#     external-node = "true"
#     external-probe = "true"
#   }
# }

# resource "consul_config_entry" "GrafanaTerminatingGateway" {
#   name = "GrafanaGateway"
#   kind = "terminating-gateway"

#   config_json = jsonencode({
#     Services = [{ Name = "${consul_service.Grafana.name}" }]
#   })
# }

resource "consul_config_entry" "GrafanaIngress" {
  name = "vps1-ingress"
  kind = "ingress-gateway"

  config_json = jsonencode({
    TLS = {
      Enabled = false
    }
    Listeners = [{
      Port     = 7880
      Protocol = "http"
      Services = [{ Name  = "grafana" }]
    }]
  })
}

# #
# # Consul Mesh DC-DC Gateway
# #

# resource "docker_config" "ConsulMeshGatewayEntryScriptConfig" {
#   name = "newconsul-entryconfig-${replace(timestamp(), ":", ".")}"
#   data = base64encode(file("${path.module}/Configs/MeshGateway/start.sh"))

#   lifecycle {
#     ignore_changes        = [name]
#     create_before_destroy = true
#   }
# }


# # resource "consul_acl_policy" "MeshGateway" {
# #   name        = "mesh-gateway"
# #   datacenters = ["dc1"]
# #   rules       = file("${path.module}/Consul/mesh-gateway-policy.hcl")
# # }

# # resource "consul_acl_token" "MeshGatewayPrimary" {
# #   description = "mesh-gateway primary datacenter token"
# #   policies = ["${consul_acl_policy.MeshGateway.name}"]
# #   local = true
# # }

# resource "docker_service" "ConsulMeshGateway" {
#   name = "ConsulMeshGateway"

#   task_spec {
#     container_spec {
#       image = "nicholasjackson/consul-envoy:v1.10.0-v1.18.3"

#       command = ["/start.sh"]

#       #
#       # TODO: Tweak this, Caddy, Prometheus, Loki, etc
#       #
#       # labels {
#       #   label = "foo.bar"
#       #   value = "baz"
#       # }

#       hostname = "ConsulMeshGateway{{.Task.Slot}}"

#       env = {
#         CONSUL_BIND_INTERFACE = "eth0"
#         CONSUL_CLIENT_INTERFACE = "eth0"
#         CONSUL_HTTP_ADDR = "tasks.Consul:8500"
#         CONSUL_GRPC_ADDR = "tasks.Consul:8502"
#         CONSUL_HTTP_TOKEN = "fb3772dd-a44b-2428-971c-c67f321fdcac"

#         MESH_HOST = "ConsulMeshGateway{{.Task.Slot}}"
#       }

#       # dir    = "/root"
#       #user   = "1000"
#       # groups = ["docker", "foogroup"]

#       # privileges {
#       #   se_linux_context {
#       #     disable = true
#       #     user    = "user-label"
#       #     role    = "role-label"
#       #     type    = "type-label"
#       #     level   = "level-label"
#       #   }
#       # }

#       # read_only = true

#       configs {
#         config_id   = docker_config.ConsulMeshGatewayEntryScriptConfig.id
#         config_name = docker_config.ConsulMeshGatewayEntryScriptConfig.name

#         file_name   = "/start.sh"
#         file_uid = "1000"
#         file_mode = 7777
#       }


#       mounts {
#         target    = "/etc/timezone"
#         source    = "/etc/timezone"
#         type      = "bind"
#         read_only = true
#       }

#       mounts {
#         target    = "/etc/localtime"
#         source    = "/etc/localtime"
#         type      = "bind"
#         read_only = true
#       }

#       # hosts {
#       #   host = "testhost"
#       #   ip   = "10.0.1.0"
#       # }


#       # dns_config {
#       #   nameservers = ["1.1.1.1", "1.0.0.1"]
#       #   search      = ["kristianjones.dev"]
#       #   options     = ["timeout:3"]
#       # }

#       #
#       # Stolon Database Secrets
#       #
#       # healthcheck {
#       #   test     = ["CMD", "curl", "-f", "http://localhost:8080/health"]
#       #   interval = "5s"
#       #   timeout  = "2s"
#       #   retries  = 4
#       # }
#     }

#     runtime      = "container"
#     networks     = [data.docker_network.meshSpineNet.id]

#     log_driver {
#       name = "loki"

#       options = {
#         loki-url = "https://loki.kristianjones.dev:443/loki/api/v1/push"
#       }
#     }
#   }

#   mode {
#     replicated {
#       replicas = 3
#     }
#   }

#   #
#   # TODO: Finetune this
#   # 
#   # update_config {
#   #   parallelism       = 1
#   #   delay             = "120s"
#   #   failure_action    = "pause"
#   #   monitor           = "30s"
#   #   max_failure_ratio = "0.1"
#   #   order             = "stop-first"
#   # }

#   # rollback_config {
#   #   parallelism       = 1
#   #   delay             = "5ms"
#   #   failure_action    = "pause"
#   #   monitor           = "10h"
#   #   max_failure_ratio = "0.9"
#   #   order             = "stop-first"
#   # }

#   endpoint_spec {
#     mode = "dnsrr"
#   }
# }

#
# Consul Ingress Gateway External-Service Mesh Gateway
# 

resource "docker_config" "ConsulIngressGatewayEntryScriptConfig" {
  name = "consulingress-entryconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/IngressGateway/start.sh"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

data "vault_generic_secret" "CONSUL_TOKEN" {
  path = "TF_INFRA/CONSUL"
}


resource "docker_service" "ConsulIngressGateway" {
  name = "ConsulIngressGateway"

  task_spec {
    container_spec {
      image = "nicholasjackson/consul-envoy:v1.10.0-v1.18.3"

      command = ["/start.sh"]

      #
      # TODO: Tweak this, Caddy, Prometheus, Loki, etc
      #
      # labels {
      #   label = "foo.bar"
      #   value = "baz"
      # }

      hostname = "ConsulIngressGateway{{.Task.Slot}}"

      env = {
        CONSUL_BIND_INTERFACE = "eth1"
        CONSUL_CLIENT_INTERFACE = "eth1"
        CONSUL_HTTP_ADDR = "vps1-raw.kristianjones.dev:8500"
        CONSUL_GRPC_ADDR = "vps1-raw.kristianjones.dev:8502"
        CONSUL_HTTP_TOKEN = "${data.vault_generic_secret.CONSUL_TOKEN.data["TOKEN"]}"

        INGRESS_HOST = "ConsulIngressGateway{{.Task.Slot}}"
        SERVICE_NAME = "${consul_config_entry.GrafanaIngress.name}"
      }

      # dir    = "/root"
      #user   = "1000"
      # groups = ["docker", "foogroup"]

      # privileges {
      #   se_linux_context {
      #     disable = true
      #     user    = "user-label"
      #     role    = "role-label"
      #     type    = "type-label"
      #     level   = "level-label"
      #   }
      # }

      # read_only = true

      configs {
        config_id   = docker_config.ConsulIngressGatewayEntryScriptConfig.id
        config_name = docker_config.ConsulIngressGatewayEntryScriptConfig.name

        file_name   = "/start.sh"
        file_uid = "1000"
        file_mode = 7777
      }


      mounts {
        target    = "/etc/timezone"
        source    = "/etc/timezone"
        type      = "bind"
        read_only = true
      }

      mounts {
        target    = "/etc/localtime"
        source    = "/etc/localtime"
        type      = "bind"
        read_only = true
      }

      # hosts {
      #   host = "testhost"
      #   ip   = "10.0.1.0"
      # }


      # dns_config {
      #   nameservers = ["1.1.1.1", "1.0.0.1"]
      #   search      = ["kristianjones.dev"]
      #   options     = ["timeout:3"]
      # }

      #
      # Stolon Database Secrets
      #
      # healthcheck {
      #   test     = ["CMD", "curl", "-f", "http://localhost:8080/health"]
      #   interval = "5s"
      #   timeout  = "2s"
      #   retries  = 4
      # }
    }

    runtime      = "container"
    networks     = [data.docker_network.meshSpineNet.id]

    log_driver {
      name = "loki"

      options = {
        loki-url = "https://loki.kristianjones.dev:443/loki/api/v1/push"
      }
    }
  }

  mode {
    replicated {
      replicas = 3
    }
  }

  #
  # TODO: Finetune this
  # 
  # update_config {
  #   parallelism       = 1
  #   delay             = "120s"
  #   failure_action    = "pause"
  #   monitor           = "30s"
  #   max_failure_ratio = "0.1"
  #   order             = "stop-first"
  # }

  # rollback_config {
  #   parallelism       = 1
  #   delay             = "5ms"
  #   failure_action    = "pause"
  #   monitor           = "10h"
  #   max_failure_ratio = "0.9"
  #   order             = "stop-first"
  # }

  endpoint_spec {
    mode = "vip"

    ports {
      name           = "grafana-ingress"
      protocol       = "tcp"
      target_port    = "7880"
      published_port = "7880"
      publish_mode   = "ingress"
    }
  }
}
