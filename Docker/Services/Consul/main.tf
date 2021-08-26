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
  }
}

data "docker_network" "meshSpineNet" {
  name = "meshSpineNet"
}


# data "docker_network" "hashicorpSpineNet" {
#   name = "hashicorpSpineNet"
# }

resource "docker_config" "ConsulConfig" {
  name = "newconsul-config-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/config.json",
      {
        SECRET_KEY = var.Secret
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
  data = base64encode(file("${path.module}/Configs/start.sh"))

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

resource "docker_service" "Consul" {
  name = "Consul"

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

      hostname = "Consul{{.Task.Slot}}"

      env = {
        CONSUL_BIND_INTERFACE = "eth0"
        CONSUL_CLIENT_INTERFACE = "eth0"
        CONSUL_HOST = "Consul{{.Task.Slot}}"
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

    force_update = 1
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
    parallelism       = 1
    delay             = "120s"
    failure_action    = "pause"
    monitor           = "30s"
    max_failure_ratio = "0.1"
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
    mode = "dnsrr"
  }
}

provider "consul" {
  address    = "tasks.Consul:8500"
  datacenter = "dc1"

  token = "e95b599e-166e-7d80-08ad-aee76e7ddf19"
}



#
# Consul Ingress
# #

# resource "consul_acl_policy" "MeshGateway" {
#   name        = "mesh-gateway"
#   datacenters = ["dc1"]
#   rules       = file("${path.module}/Consul/mesh-gateway-policy.hcl")
# }

# resource "consul_acl_token" "MeshGatewayPrimary" {
#   description = "mesh-gateway primary datacenter token"
#   policies = ["${consul_acl_policy.MeshGateway.name}"]
#   local = true
# }

# resource "docker_service" "ConsulIngressProxy" {
#   name = "ConsulIngressProxy"

#   task_spec {
#     container_spec {
#       image = "nicholasjackson/consul-envoy:v1.10.0-v1.18.3"

#       args = [
#         "consul",
#         "connect",
#         "envoy",
#         "-gateway=mesh",
#         "-register",
#         "-address=ConsulIngressProxy:8443",
#         "-bind-address=IngressProxy=0.0.0.0:8443",
#         "-token=${consul_acl_token.MeshGatewayPrimary.accessor_id}"
#       ]

#       #
#       # TODO: Tweak this, Caddy, Prometheus, Loki, etc
#       #
#       # labels {
#       #   label = "foo.bar"
#       #   value = "baz"
#       # }

#       hostname = "ConsulIngressProxy{{.Task.Slot}}"

#       env = {
#         CONSUL_BIND_INTERFACE = "eth0"
#         CONSUL_CLIENT_INTERFACE = "eth0"
#         CONSUL_HTTP_ADDR = "tasks.Consul:8500"
#         CONSUL_GRPC_ADDR = "tasks.Consul:8502"
#         CONSUL_HTTP_TOKEN = "${consul_acl_token.MeshGatewayPrimary.accessor_id}"
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

#     force_update = 1
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
#   update_config {
#     parallelism       = 1
#     delay             = "120s"
#     failure_action    = "pause"
#     monitor           = "30s"
#     max_failure_ratio = "0.1"
#     order             = "stop-first"
#   }

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