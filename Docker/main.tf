terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "2.15.0"
    }

    minio = {
      source  = "aminueza/minio"
      version = "1.2.0"
    }

    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }

    vault = {
      source = "hashicorp/vault"
      version = "2.22.1"
    }
  }
}

data "vault_generic_secret" "minio" {
  path = "keycloak/MINIO"
}

data "vault_generic_secret" "pgAuth" {
  path = "keycloak/STOLON"
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

#
# Networks
#

#
# Network for containers being served directly to the 
# outside world without any filtering. Top level applications 
# and sub proxies occupy this class and all ingress proxies 
# and their sub levels
#
# Network Space: 172.30.200.0/22
#
data "docker_network" "publicSpineNet" {
  name = "publicSpineNet"
}

#
# Network for containers with AAA although 
# no logging/tracking/auditing, 
# and no ingress filtering (Storage/VPN)
#
# Network Space: 172.30.204.0/22
#
data "docker_network" "protectedSpineNet" {
  name = "protectedSpineNet"
}

#
# Network for audited, strongly filtered, 
# AAA and logged traffic (Storage, Insights, etc)
#
# Network Space: 172.30.208.0/22
#
data "docker_network" "secureSpineNet" {
  name = "secureSpineNet"
}

#
# Network for M2M Communication, also known as a backend network
#
# Network Space: 172.30.212.0/22
#

data "docker_network" "meshSpineNet" {
  name = "meshSpineNet"
}



#
# AAA Stack
#






#
# Terraform Managed Networks
#
resource "docker_network" "OpenNMSIntNetwork" {
  name = "opennms-intnetwork"

  attachable = true
  
  driver = "overlay"

  internal = false

  ipam_config {
    subnet = "172.30.240.64/27"

    gateway = "172.30.240.65"

    aux_address = {}
  }
}

#
# Network for secured, audited, protected M2M communications
#
# Network Space: 172.30.216.0/21
#

resource "docker_network" "meshIntSpineNet" {
  name = "meshIntSpineNet"

  attachable = true
  
  driver = "overlay"

  internal = false

  ipam_config {
    subnet = "172.30.216.0/21"

    gateway = "172.30.216.1"

    aux_address = {}
  }
}

#
# Insights Stack
#
# Network Space: 172.30.238.0/23
#

#
# Networks
#

#
# Insight Spine Network
#
# Reverse Proxy, Cross Service Communication
#
# Network Space: 172.30.239.128/25
#
data "docker_network" "insightsSpineNet" {
  name = "insightsSpineNet"
}

#
# Backend Network for Grafana Loki
#
# Network Space: 172.30.238.0/27
#
resource "docker_network" "lokiSpineNet" {
  name = "insights-lokispinenet"

  attachable = true
  
  driver = "overlay"

  internal = false

  ipam_config {
    subnet = "172.30.238.0/27"

    gateway = "172.30.238.1"

    aux_address = {}
  }
}

#
# Grafana
#
# Website: https://grafana.com/
# Docs: https://grafana.com/docs/grafana/latest/
# Config Reference: https://grafana.com/docs/grafana/latest/administration/configuration/
#

# Grafana Main Configuration File
resource "docker_config" "GrafanaIniConfig" {
  name = "grafana-grafanaini-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/Insights/Grafana/Grafana.ini",
      {
        VERSION = "1.3.10"
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_secret" "GrafanaDBName" {
  name = "grafana-dbname-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    "${var.StolonGrafanaDB.name}"
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_secret" "GrafanaDBUser" {
  name = "grafana-dbuser-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    "${var.StolonGrafanaRole.name}"
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_secret" "GrafanaDBPassword" {
  name = "grafana-dbpassword-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    "${var.StolonGrafanaRole.password}"
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}


resource "docker_service" "Grafana" {
  name = "Grafana"

  task_spec {
    container_spec {
      image = "grafana/grafana:8.0.3"

      hostname = "Grafana"

      env = {
        GF_LOG_MODE = "console"

        #
        # Grafana Database
        #
        GF_DATABASE_NAME__FILE = "/run/secrets/DB_NAME"
        GF_DATABASE_USER__FILE = "/run/secrets/DB_USER"
        GF_DATABASE_PASSWORD__FILE = "/run/secrets/DB_PASSWORD"
      }

      #
      # Grafana Configuration
      #
      configs {
        config_id   = docker_config.GrafanaIniConfig.id
        config_name = docker_config.GrafanaIniConfig.name

        file_name   = "/etc/grafana/grafana.ini"
      }

      #
      # Grafana Database
      #
      secrets {
        secret_id   = docker_secret.GrafanaDBName.id
        secret_name = docker_secret.GrafanaDBName.name

        file_name   = "/run/secrets/DB_NAME"
      }

      secrets {
        secret_id   = docker_secret.GrafanaDBUser.id
        secret_name = docker_secret.GrafanaDBUser.name

        file_name   = "/run/secrets/DB_USER"
      }

      secrets {
        secret_id   = docker_secret.GrafanaDBPassword.id
        secret_name = docker_secret.GrafanaDBPassword.name

        file_name   = "/run/secrets/DB_PASSWORD"
      }

    }

    #
    # TODO: Fine Tune
    #

    # resources {
    #   limits {
    #     memory_bytes = 16777216
    #   }
    # }

    force_update = 0
    runtime      = "container"

    networks     = [docker_network.meshIntSpineNet.id, data.docker_network.meshSpineNet.id, data.docker_network.insightsSpineNet.id]

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
  #   delay             = "10s"
  #   failure_action    = "pause"
  #   monitor           = "5s"
  #   max_failure_ratio = "0.1"
  #   order             = "start-first"
  # }

  # rollback_config {
  #   parallelism       = 1
  #   delay             = "5ms"
  #   failure_action    = "pause"
  #   monitor           = "10h"
  #   max_failure_ratio = "0.9"
  #   order             = "stop-first"
  # }
}

#
# Grafana Cortex
#
# Website: https://cortexmetrics.io/
# Docs: https://cortexmetrics.io/docs/
# Config Reference: https://cortexmetrics.io/docs/configuration/configuration-file/
#


#
# Grafana Loki
# 
# Website:
# Docs:
# Config Reference: https://grafana.com/docs/loki/latest/configuration/

#
# AAA Stack
#

##
# 
# AAA Spiune Network
#
# Network Space: 172.30.225.128/25
#
data "docker_network" "AAASpineNet" {
  name = "AAASpineNet"
}

#
# Keycloak
#

#
# Keycloak Database Secrets
#

resource "docker_secret" "KeycloakDBUser" {
  name = "keycloak-dbuser-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    "${var.StolonKeycloakRole.name}"
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_secret" "KeycloakDBPassword" {
  name = "keycloak-dbpassword-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    "${var.StolonKeycloakRole.password}"
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

#
# Keycloak Initial Admin Secret
#

data "vault_generic_secret" "KeycloakAdmin" {
  path = "keycloak/KEYCLOAK_ADMIN"
}

#
# Keycloak Configuration
#

#
# Keycloak Bootstrap Scripts
#
resource "docker_config" "KeycloakEntrypointScript" {
  name = "keycloak-entrypointscript-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/Keycloak/Scripts/Entrypoint.sh",
      {
        VERSION = "1.3.10"
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_config" "KeycloakRADIUSHACLI" {
  name = "keycloak-radiushacli-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/Keycloak/CLI/radius-ha.cli"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_config" "KeycloakRADIUSCLI" {
  name = "keycloak-radiuscli-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/Keycloak/CLI/radius.cli"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

#
# RADIUS Configuration
#

resource "random_password" "RADIUSSecret" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "docker_config" "KeycloakRADIUSConfig" {
  name = "keycloak-radiusconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/Keycloak/Configs/radius.config",
      {
        SECRET = "${random_password.RADIUSSecret.result}"
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}


resource "docker_service" "Keycloak" {
  name = "AAA-Keycloak"

  task_spec {
    container_spec {
      image = "quay.io/keycloak/keycloak:latest"

      #
      # TODO: Tweak this, Caddy, Prometheus, Loki, etc
      #
      # labels {
      #   label = "foo.bar"
      #   value = "baz"
      # }

      command = ["/entry.sh"]

      hostname = "Keycloak"

      env = {
        PROXY_ADDRESS_FORWARDING = "TRUE"

        #
        # Database
        #
        DB_VENDOR = "postgres"
        DB_ADDR = "tasks.StolonProxy"
        DB_PORT = "5432"
        DB_DATABASE = "${var.StolonKeycloakDB.name}"

        #
        # Database Auth
        #
        DB_USER_FILE = "/run/secrets/DB_USER"
        DB_PASSWORD_FILE = "/run/secrets/DB_PASSWORD"
        DB_SCHEMA = "public"

        #
        # Initial Admin User
        #
        # TODO: Remove this from Vault and Autogenerate within Terraform with random_password
        #
        # The reason this isn't done already is because this is a migration from an existing Swarm Stack Service that I'm moving to Terraform
        #
        KEYCLOAK_USER = "${data.vault_generic_secret.KeycloakAdmin.data["USERNAME"]}"
        KEYCLOAK_PASSWORD = "${data.vault_generic_secret.KeycloakAdmin.data["PASSWORD"]}"

        #
        # Clustering
        #
        # TODO: Learn more about Keycloak Clustering, and Caching
        #
        DOCKER_SWARM = "true"

        CACHE_OWNERS_COUNT = "3"
        CACHE_OWNERS_AUTH_SESSIONS_COUNT = "3"
        JGROUPS_DISCOVERY_PROTOCOL = "dns.DNS_PING"
        JGROUPS_DISCOVERY_PROPERTIES = "dns_query=tasks.AAA-Keycloak"

        #
        # Misc
        #
        KEYCLOAK_STATISTICS = "all"
        TZ = "America/Winnipeg"
        "keycloak.profile.feature.upload_scripts" = "enabled"
      }

      # dir    = "/root"
      user   = "root"
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

      configs {
        config_id   = docker_config.KeycloakEntrypointScript.id
        config_name = docker_config.KeycloakEntrypointScript.name

        file_name   = "/entry.sh"
        file_uid = "1000"
        file_mode = 7777
      }
      
      # Database Username
      secrets {
        secret_id   = docker_secret.KeycloakDBUser.id
        secret_name = docker_secret.KeycloakDBUser.name

        file_name   = "/run/secrets/DB_USER"
        file_uid    = "1000"
        file_gid    = "0"
        file_mode   = 0777
      }

      # Database Password
      secrets {
        secret_id   = docker_secret.KeycloakDBPassword.id
        secret_name = docker_secret.KeycloakDBPassword.name

        file_name   = "/run/secrets/DB_PASSWORD"
        file_uid    = "1000"
        file_gid    = "0"
        file_mode   = 0777
      }

      configs {
        config_id   = docker_config.KeycloakEntrypointScript.id
        config_name = docker_config.KeycloakEntrypointScript.name

        file_name   = "/opt/radius/scripts/docker-entrypoint.sh"
        file_uid = "1000"
        file_mode = 7777
      }

      configs {
        config_id   = docker_config.KeycloakRADIUSConfig.id
        config_name = docker_config.KeycloakRADIUSConfig.name

        file_name   = "/config/radius.config"

        file_mode = 0777
      }

      #
      # RADIUS CLI
      #
      configs {
        config_id   = docker_config.KeycloakRADIUSHACLI.id
        config_name = docker_config.KeycloakRADIUSHACLI.name

        file_name   = "/opt/radius/cli/radius-ha.cli"
        file_uid = "1000"
        file_mode = 0777
      }

      configs {
        config_id   = docker_config.KeycloakRADIUSCLI.id
        config_name = docker_config.KeycloakRADIUSCLI.name

        file_name   = "/opt/radius/cli/radius.cli"
        file_uid = "1000"
        file_mode = 0777
      }
    }

    force_update = 1
    runtime      = "container"
    networks     = [data.docker_network.AAASpineNet.id, data.docker_network.protectedSpineNet.id, data.docker_network.meshSpineNet.id]
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
  #   delay             = "10s"
  #   failure_action    = "pause"
  #   monitor           = "5s"
  #   max_failure_ratio = "0.1"
  #   order             = "start-first"
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
    mode = "dnsrr"
  }
}

#
# Bitwarden
#
resource "docker_service" "Bitwarden" {
  name = "AAA-Bitwarden"

  task_spec {
    container_spec {
      image = "vaultwarden/server:alpine"

      #
      # TODO: Tweak this, Caddy, Prometheus, Loki, etc
      #
      # labels {
      #   label = "foo.bar"
      #   value = "baz"
      # }

      hostname = "Bitwarden"

      env = {
        WEBSOCKET_ENABLED = "true"
        ROCKET_PORT = "8080"
        DATABASE_URL = "postgresql://${var.StolonBitwardenRole.name}:${var.StolonBitwardenRole.password}@tasks.StolonProxy:5432/${var.StolonBitwardenDB.name}"
      }

      # dir    = "/root"
      user   = "1000"
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
        target    = "/data"
        source    = "bitwarden-backup"
        type      = "volume"

        volume_options {
          driver_name = "s3core-storage"
        }
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
    networks     = [data.docker_network.publicSpineNet.id, data.docker_network.meshSpineNet.id]
  }

  mode {
    replicated {
      replicas = 1
    }
  }

  #
  # TODO: Finetune this
  # 
  # update_config {
  #   parallelism       = 1
  #   delay             = "10s"
  #   failure_action    = "pause"
  #   monitor           = "5s"
  #   max_failure_ratio = "0.1"
  #   order             = "start-first"
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
    mode = "dnsrr"
  }
}

#
# Alpine Lab
#

#
# Script/Config Test #1
#

resource "docker_config" "AlpineScriptTest1Entry" {
  name = "alpinelab-scripttest1-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/AlpineTests/AlpineScriptTest1/entry.sh"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

#
# TODO: Get Docker Config Templates working in Provider
#

# resource "docker_service" "AlpineScriptTest1" {
#   name = "AlpineScriptTest"

#   task_spec {
#     container_spec {
#       image = "alpine:3.14.1"

#       #
#       # TODO: Tweak this, Caddy, Prometheus, Loki, etc
#       #
#       # labels {
#       #   label = "foo.bar"
#       #   value = "baz"
#       # }

#       command = ["/entry.sh"]
#       args = []

#       hostname = "AlpineScriptTest{{.Task.Slot}}"

#       env = {
#         TEST = "HELLO{{.Task.Slot}}"
#       }

#       # dir    = "/root"
#       user   = "root"
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


#       # dns_config {
#       #   nameservers = ["1.1.1.1", "1.0.0.1"]
#       #   search      = ["kristianjones.dev"]
#       #   options     = ["timeout:3"]
#       # }

#       configs {
#         config_id   = docker_config.AlpineScriptTest1Entry.id
#         config_name = docker_config.AlpineScriptTest1Entry.name

#         file_name   = "/entry.sh"
#         file_uid = "1000"
#         file_mode = 7777
#       }

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
#   #   delay             = "10s"
#   #   failure_action    = "pause"
#   #   monitor           = "5s"
#   #   max_failure_ratio = "0.1"
#   #   order             = "start-first"
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
# TFTP
#

resource "docker_service" "TFTPd" {
  name = "TFTPd"

  task_spec {
    container_spec {
      image = "kristianfoss/programs-tftpd:tftpd-stable-scratch"

      args = ["-E", "0.0.0.0", "8069", "tftpd", "-u", "user", "-c", "/data"]

      #
      # TODO: Get CHWON/CHMOD Volume/Init
      #
      mounts {
        target    = "/data"
        source    = var.TFTPBucket.bucket
        type      = "volume"

        volume_options {
          driver_name = "s3core-storage"
        }
      }
    }

    resources {
      limits {
        memory_bytes = 16777216
      }
    }

    force_update = 0
    runtime      = "container"

    networks     = [docker_network.meshIntSpineNet.id]

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
  #   delay             = "10s"
  #   failure_action    = "pause"
  #   monitor           = "5s"
  #   max_failure_ratio = "0.1"
  #   order             = "start-first"
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
    mode = "dnsrr"
  }
}

###############
#
# INGRESS
#
#
#

###########
# Meshery #
###########

# resource "docker_service" "ConsulEnvoy" {
#   name = "Meshery"

#   task_spec {
#     container_spec {
#       image = "nicholasjackson/consul-envoy:v1.10.0-v1.18.3"

#       command = ["bash", "-c"]


#       args = ["consul", "connect", "envoy", "-sidecar-for=web-v1"]

#       user   = "1000"

#       env = {
#         CONSUL_HTTP_ADDR = "tasks.ConsulCore"
#       }

#       # mounts {
#       #   target    = "/data"
#       #   source    = var.TFTPBucket.bucket
#       #   type      = "volume"

#       #   volume_options {
#       #     driver_name = "s3core-storage"
#       #   }
#       # }
#     }

#     force_update = 0
#     runtime      = "container"

#     networks     = [data.docker_network.protectedSpineNet.id, data.docker_network.meshSpineNet.id]

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
#   #   delay             = "10s"
#   #   failure_action    = "pause"
#   #   monitor           = "5s"
#   #   max_failure_ratio = "0.1"
#   #   order             = "start-first"
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
#     ports {
#       name           = "tftp"
#       protocol       = "udp"
#       target_port    = "8069"
#       published_port = "69"
#       publish_mode   = "ingress"
#     }
#   }
# }


#
# Envoy Proxy
# 

# resource "docker_config" "FrontEnvoyCoreConfig" {
#   name = "envoy-front-coreconfig-${replace(timestamp(), ":", ".")}"
#   data = base64encode(
#     templatefile("${path.module}/Configs/Envoy/FrontEnvoy/envoy.yaml",
#       {
#         DATABASE_HOST = "tasks.StolonProxy",
#         DATABASE_PORT = 5432,

#         DATABASE_NAME = "${var.StolonOpenNMSDB.name}",

#         DATABASE_USERNAME = "${var.StolonOpenNMSRole.name}",
#         DATABASE_PASSWORD = "${var.StolonOpenNMSRole.password}",
        
#         #
#         # Postgres ADMIN
#         #
#         # TODO: Determine if OpenNMS User Suffices
#         #
#         POSTGRES_USERNAME = "${data.vault_generic_secret.pgAuth.data["USERNAME"]}",
#         POSTGRES_PASSWORD = "${data.vault_generic_secret.pgAuth.data["PASSWORD"]}"
#       }
#     )
#   )

#   lifecycle {
#     ignore_changes        = [name]
#     create_before_destroy = true
#   }
# }


# resource "docker_service" "FrontEnvoy" {
#   name = "FrontEnvoy"

#   task_spec {
#     container_spec {
#       image = "envoyproxy/envoy-alpine:v1.19-latest"

#       user   = "envoy"

#       configs {
#         config_id   = docker_config.OpenNMSConfigConfig.id
#         config_name = docker_config.OpenNMSConfigConfig.name

#         file_name   = "/etc/confd/confd.toml"
#       }

#     }

#     force_update = 0
#     runtime      = "container"

#     networks     = [data.docker_network.publicSpineNet.id, data.docker_network.meshSpineNet.id]

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
#   #   delay             = "10s"
#   #   failure_action    = "pause"
#   #   monitor           = "5s"
#   #   max_failure_ratio = "0.1"
#   #   order             = "start-first"
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
#     ports {
#       name           = "envoytest1"
#       protocol       = "tcp"
#       target_port    = "8000"
#       published_port = "8000"
#       publish_mode   = "ingress"
#     }
#   }
# }

#
# NetBox
#

resource "random_password" "NetBoxSecret" {
  length           = 50
  special          = true
  override_special = "_%@"
}

resource "docker_service" "Netbox" {
  name = "Netbox"

  task_spec {
    container_spec {
      image = "netboxcommunity/netbox:snapshot"

      hostname = "Netbox"

      env = {
        DB_HOST = "tasks.StolonProxy"
        DB_NAME = "${var.StolonNetboxDB.name}"

        DB_USER = "${var.StolonOpenNMSRole.name}"
        DB_PASSWORD = "${var.StolonOpenNMSRole.password}"

        SECRET_KEY = "${random_password.NetBoxSecret.result}"

        REMOTE_AUTH_ENABLED = "True"

        REMOTE_AUTH_HEADER = "HTTP_X_TOKEN_USER_NAME"
        REMOTE_AUTH_DEFAULT_PERMISSIONS = "None"
      }
    }

    #
    # TODO: Finetune this
    #
    # resources {
    #   limits {
    #     memory_bytes = 16777216
    #   }
    # }

    force_update = 0
    runtime      = "container"

    networks     = [data.docker_network.meshSpineNet.id, data.docker_network.protectedSpineNet.id]

    log_driver {
      name = "loki"

      options = {
        loki-url = "https://loki.kristianjones.dev:443/loki/api/v1/push"
      }
    }
  }

  mode {
    replicated {
      replicas = 1
    }
  }

  #
  # TODO: Finetune this
  # 
  # update_config {
  #   parallelism       = 1
  #   delay             = "10s"
  #   failure_action    = "pause"
  #   monitor           = "5s"
  #   max_failure_ratio = "0.1"
  #   order             = "start-first"
  # }

  # rollback_config {
  #   parallelism       = 1
  #   delay             = "5ms"
  #   failure_action    = "pause"
  #   monitor           = "10h"
  #   max_failure_ratio = "0.9"
  #   order             = "stop-first"
  # }
}



#
# OpenNMS
#

#
# Datasource Configuration
#
resource "docker_config" "OpenNMSDatasourceConfig" {
  name = "opennms-datasoruceconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/OpenNMS/opennms-datasources.xml",
      {
        DATABASE_HOST = "tasks.StolonProxy",
        DATABASE_PORT = 5432,

        DATABASE_NAME = "${var.StolonOpenNMSDB.name}",

        DATABASE_USERNAME = "${var.StolonOpenNMSRole.name}",
        DATABASE_PASSWORD = "${var.StolonOpenNMSRole.password}",
        
        #
        # Postgres ADMIN
        #
        # TODO: Determine if OpenNMS User Suffices
        #
        POSTGRES_USERNAME = "${data.vault_generic_secret.pgAuth.data["USERNAME"]}",
        POSTGRES_PASSWORD = "${data.vault_generic_secret.pgAuth.data["PASSWORD"]}"
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_config" "OpenNMSHorizionConfig" {
  name = "opennms-horizionconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/OpenNMS/horizon-config.yaml",
      {
        DATABASE_HOST = "tasks.StolonProxy",
        DATABASE_PORT = 5432,

        DATABASE_NAME = "${var.StolonOpenNMSDB.name}",

        DATABASE_USERNAME = "${var.StolonOpenNMSRole.name}",
        DATABASE_PASSWORD = "${var.StolonOpenNMSRole.password}",
        
        #
        # Postgres ADMIN
        #
        # TODO: Determine if OpenNMS User Suffices
        #
        POSTGRES_USERNAME = "${data.vault_generic_secret.pgAuth.data["USERNAME"]}",
        POSTGRES_PASSWORD = "${data.vault_generic_secret.pgAuth.data["PASSWORD"]}"
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_config" "OpenNMSConfigConfig" {
  name = "opennms-configconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/OpenNMS/confd.toml"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_config" "OpenNMSPropertiesConfig" {
  name = "opennms-properties-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/OpenNMS/opennms.properties"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}


# resource "docker_service" "OpenNMSCassandra" {
#   name = "OpenNMSCassandra"

#   task_spec {
#     container_spec {
#       image = "cassandra:3.11.11"
#       hostname = "OpenNMSCassandra"

#       env = {
#         CASSANDRA_CLUSTER_NAME = "opennms-newts"
#         CASSANDRA_DC = "opennms-lab"
#         CASSANDRA_RACK = "opennms-lab-rack"
#         CASSANDRA_ENDPOINT_SNITCH = "GossipingPropertyFileSnitch"

#         #
#         # JMX
#         #
#         # TODO: What's this doing
#         #
#         LOCAL_JMX = "false"
#         JMX_HOST = "127.0.0.1"

#         #
#         # MISC
#         #
#         TZ = "America/Winnipeg"
#       }

#       mounts {
#         target    = "/var/lib/cassandra"
#         source    = var.OpenNMSCassandraBucket.bucket
#         type      = "volume"

#         volume_options {
#           driver_name = "s3core-storage"
#         }
#       }
#     }

#     force_update = 0
#     runtime      = "container"

#     networks     = [docker_network.OpenNMSIntNetwork.id]

#     log_driver {
#       name = "loki"

#       options = {
#         loki-url = "https://loki.kristianjones.dev:443/loki/api/v1/push"
#       }
#     }
#   }

#   mode {
#     replicated {
#       replicas = 1
#     }
#   }

#   #
#   # TODO: Finetune this
#   # 
#   # update_config {
#   #   parallelism       = 1
#   #   delay             = "10s"
#   #   failure_action    = "pause"
#   #   monitor           = "5s"
#   #   max_failure_ratio = "0.1"
#   #   order             = "start-first"
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

resource "docker_service" "OpenNMS" {
  name = "OpenNMS"

  task_spec {
    container_spec {
      image = "opennms/horizon:28.0.2"

      args = ["-f"]
      hostname = "OpenNMS"

      env = {
        #
        # Database
        #
        POSTGRES_HOST = "tasks.StolonProxy",
        POSTGRES_PORT = 5432,

        OPENNMS_DBNAME = "${var.StolonOpenNMSDB.name}"

        OPENNMS_DBUSER = "${var.StolonOpenNMSRole.name}"
        OPENNMS_DBPASS = "${var.StolonOpenNMSRole.password}"
        
        #
        # Postgres ADMIN
        #
        # TODO: Determine if OpenNMS User Suffices
        #
        POSTGRES_USER = "${data.vault_generic_secret.pgAuth.data["USERNAME"]}"
        POSTGRES_PASSWORD = "${data.vault_generic_secret.pgAuth.data["PASSWORD"]}"

        #
        # MISC
        #
        TZ = "America/Winnipeg"

        OPENNMS_HTTP_URL = "https://opennms.kristianjones.dev"

        OPENNMS_HOME = "/opt/opennms"
      }

      #
      # https://github.com/opennms-forge/stack-play/blob/master/full-stack/container-fs/horizon/etc/conf.d/confd.toml
      #
      # configs {
      #   config_id   = docker_config.OpenNMSConfigConfig.id
      #   config_name = docker_config.OpenNMSConfigConfig.name

      #   file_name   = "/etc/confd/confd.toml"
      # }

      # configs {
      #   config_id   = docker_config.OpenNMSHorizionConfig.id
      #   config_name = docker_config.OpenNMSHorizionConfig.name

      #   file_name   = "/opt/opennms-overlay/confd/horizon-config.yaml"
      # }

      configs {
        config_id   = docker_config.OpenNMSPropertiesConfig.id
        config_name = docker_config.OpenNMSPropertiesConfig.name

        file_name   = "/opt/opennms/etc/opennms.properties"
      }


      #
      # OpenNMS Data Volume
      #
      # TODO: Determine Data Storage and if this is necessary
      #
      mounts {
        target    = "/opennms-data"
        source    = var.OpenNMSDataBucket.bucket
        type      = "volume"

        volume_options {
          driver_name = "s3core-storage"
        }
      }

      # mounts {
      #   target    = "/opt/opennms/deploy"
      #   source    = var.OpenNMSDeployDataBucket.bucket
      #   type      = "volume"

      #   volume_options {
      #     driver_name = "s3core-storage"
      #   }
      # }

      # mounts {
      #   target    = "/opt/opennms/data"
      #   source    = var.OpenNMSCoreDataBucket.bucket
      #   type      = "volume"

      #   volume_options {
      #     driver_name = "s3core-storage"
      #   }
      # }

      #
      # OpenNMS Config Volume
      #
      # TODO: Move as much as possible to dynamic configs
      #
      mounts {
        target    = "/opt/opennms/etc"
        source    = var.OpenNMSConfigBucket.bucket
        type      = "volume"

        volume_options {
          driver_name = "s3core-storage"
        }
      }
    }

    resources {
      limits {
        memory_bytes = 2310611911
      }
    }

    force_update = 0
    runtime      = "container"
    networks     = [data.docker_network.meshSpineNet.id, data.docker_network.protectedSpineNet.id, docker_network.OpenNMSIntNetwork.id]

    log_driver {
      name = "loki"

      options = {
        loki-url = "https://loki.kristianjones.dev:443/loki/api/v1/push"
      }
    }
  }

  mode {
    replicated {
      replicas = 1
    }
  }

  #
  # TODO: Finetune this
  # 
  # update_config {
  #   parallelism       = 1
  #   delay             = "10s"
  #   failure_action    = "pause"
  #   monitor           = "5s"
  #   max_failure_ratio = "0.1"
  #   order             = "start-first"
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
    mode = "dnsrr"

  }
}

#
# Network Stack
#
# Network Space: 172.30.240.0/23
# 

#
# Network Stack Spine Network
#
# Network Space: 172.30.241.128/25
#
data "docker_network" "networkSpineNet" {
  name = "networkSpineNet"
}

#
# ISC Networking
#

#
# Kea DHCP
#

resource "docker_config" "DHCPConfig" {
  name = "network-dhcpcore-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/DHCP/config.jsonc",
      {
        DB_HOST = "tasks.StolonProxy",

        DB_NAME = "${var.StolonDHCPDB.name}",

        DB_USERNAME = "${var.StolonDHCPRole.name}",
        DB_PASSWORD = "${var.StolonDHCPRole.password}"
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_config" "DHCPCTRLAgentConfig" {
  name = "network-dhcpctrlagentconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/DHCP/keactrl.conf"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_config" "DHCPCTRLConfig" {
  name = "network-dhcpctrlconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/DHCP/kea-ctrl-agent.jsonc"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_service" "DHCP" {
  name = "DHCP"

  task_spec {
    container_spec {
      image = "kristianfjones/kea:vps1-core"

      command = ["/usr/sbin/keactrl"]
      args = ["start", "-c", "/config/keactrl.conf"]

      env = {
        TZ = "America/Winnipeg"
      }

      configs {
        config_id   = docker_config.DHCPConfig.id
        config_name = docker_config.DHCPConfig.name

        file_name   = "/config/dhcp4.json"
      }

      configs {
        config_id   = docker_config.DHCPCTRLAgentConfig.id
        config_name = docker_config.DHCPCTRLAgentConfig.name

        file_name   = "/config/keactrl.conf"
      }

      configs {
        config_id   = docker_config.DHCPCTRLConfig.id
        config_name = docker_config.DHCPCTRLConfig.name

        file_name   = "/config/kea-ctrl-agent.json"
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
    }

    force_update = 0
    runtime      = "container"

    networks     = [data.docker_network.meshSpineNet.id, docker_network.meshIntSpineNet.id]

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
  #   delay             = "10s"
  #   failure_action    = "pause"
  #   monitor           = "5s"
  #   max_failure_ratio = "0.1"
  #   order             = "start-first"
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
    mode = "dnsrr"
  }
}

#
# ISC Stork
#

resource "docker_service" "StorkServer" {
  name = "StorkServer"

  task_spec {
    container_spec {
      image = "registry.gitlab.isc.org/isc-projects/stork/server:latest"

      #
      # TODO: Finetune this
      #
      # command = ["/usr/sbin/kea-dhcp4"]
      # args = ["-c", "/config/config.json"]

      env = {
        #
        # Stork Database
        #
        STORK_DATABASE_HOST = "tasks.StolonProxy"
        STORK_DATABASE_PORT = "5432"

        STORK_DATABASE_NAME = "${var.StolonStorkDB.name}"

        STORK_DATABASE_USER_NAME = "${var.StolonStorkRole.name}"
        STORK_DATABASE_PASSWORD = "${var.StolonStorkRole.password}"

        #
        # MISC
        #
        TZ = "America/Winnipeg"
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
    }

    force_update = 0
    runtime      = "container"

    networks     = [data.docker_network.meshSpineNet.id, docker_network.meshIntSpineNet.id]

    log_driver {
      name = "loki"

      options = {
        loki-url = "https://loki.kristianjones.dev:443/loki/api/v1/push"
      }
    }
  }

  mode {
    #
    # TODO: Scale/Replicate
    #
    replicated {
      replicas = 1
    }
  }

  #
  # TODO: Finetune this
  # 
  # update_config {
  #   parallelism       = 1
  #   delay             = "10s"
  #   failure_action    = "pause"
  #   monitor           = "5s"
  #   max_failure_ratio = "0.1"
  #   order             = "start-first"
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
    mode = "dnsrr"
  }
}

resource "docker_service" "StorkUI" {
  name = "StorkUI"

  task_spec {
    container_spec {
      image = "registry.gitlab.isc.org/isc-projects/stork/webui:latest"

      #
      # TODO: Finetune this
      #
      # command = ["/usr/sbin/kea-dhcp4"]
      # args = ["-c", "/config/config.json"]

      env = {
        API_HOST = "tasks.StorkServer"
        API_PORT = "8080"


        #
        # MISC
        #
        TZ = "America/Winnipeg"
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
    }

    force_update = 0
    runtime      = "container"

    networks     = [data.docker_network.meshSpineNet.id, data.docker_network.networkSpineNet.id]

    log_driver {
      name = "loki"

      options = {
        loki-url = "https://loki.kristianjones.dev:443/loki/api/v1/push"
      }
    }
  }

  mode {
    #
    # TODO: Scale/Replicate
    #
    replicated {
      replicas = 1
    }
  }

  #
  # TODO: Finetune this
  # 
  # update_config {
  #   parallelism       = 1
  #   delay             = "10s"
  #   failure_action    = "pause"
  #   monitor           = "5s"
  #   max_failure_ratio = "0.1"
  #   order             = "start-first"
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
    mode = "dnsrr"
  }
}

#
# Ingress
#

#
# GoBetween
#
resource "docker_config" "GoBetweenConfig" {
  name = "gobetween-coreconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/GoBetween/config.toml"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_service" "GoBetween" {
  name = "GoBetween"

  task_spec {
    container_spec {
      image = "yyyar/gobetween"

      command = ["/gobetween"]
      args = ["-c", "/Config/config.toml"]

      env = {
        TZ = "America/Winnipeg"
      }

      configs {
        config_id   = docker_config.GoBetweenConfig.id
        config_name = docker_config.GoBetweenConfig.name

        file_name   = "/Config/config.toml"
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
    }

    force_update = 0
    runtime      = "container"

    networks     = [data.docker_network.meshSpineNet.id, docker_network.meshIntSpineNet.id]

    log_driver {
      name = "loki"

      options = {
        loki-url = "https://loki.kristianjones.dev:443/loki/api/v1/push"
      }
    }
  }

  mode {
    global = true
  }

  #
  # TODO: Finetune this
  # 
  # update_config {
  #   parallelism       = 1
  #   delay             = "10s"
  #   failure_action    = "pause"
  #   monitor           = "5s"
  #   max_failure_ratio = "0.1"
  #   order             = "start-first"
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
    ports {
      name           = "dnstest1"
      protocol       = "udp"
      target_port    = "15853"
      published_port = "15853"
      publish_mode   = "host"
    }

    #
    # TFTP
    #
    ports {
      name           = "tftp"
      protocol       = "udp"
      target_port    = "69"
      published_port = "69"
      publish_mode   = "ingress"
    }

    #
    # DHCP
    #
    ports {
      name           = "dchp1"
      protocol       = "udp"
      target_port    = "67"
      published_port = "67"
      publish_mode   = "ingress"
    }

    ports {
      name           = "dhcp2"
      protocol       = "udp"
      target_port    = "68"
      published_port = "68"
      publish_mode   = "ingress"
    }
  }
}

# resource "docker_plugin" "s3core-storage" {
#   name                  = "rexray/s3fs"
#   alias                 = "s3core-storagenew"

#   enabled               = true
#   grant_all_permissions = true
#   enable_timeout        = 300

#   force_destroy         = false
#   force_disable         = false

#   env = [
#     "S3FS_OPTIONS=allow_other,use_path_request_style,url=${var.minioURL}",
#     "S3FS_ENDPOINT=${var.minioURL}",
#     "S3FS_ACCESSKEY=${data.vault_generic_secret.minio.data["ACCESS_KEY"]}",
#     "S3FS_SECRETKEY=${data.vault_generic_secret.minio.data["SECRET_KEY"]}"
#   ]

#   lifecycle {
#     ignore_changes = [
#       # Ignore changes to tags, e.g. because a management agent
#       # updates these based on some ruleset managed elsewhere.
#       env,
#       id,
#     ]
#   }
# }

# data "docker_network" "storageIntWeb" {
#   name = "storageIntWeb"
# }

# data "docker_network" "coreAuthWeb" {
#   name = "authWeb"
# }

# resource "docker_container" "DHCPDatabase" {
#   name    = "dhcpDatabase"
#   image   = "mariadb:10"

#   cpu_shares      = 4
#   memory = 256

#   dns        = ["1.1.1.1", "1.0.0.1"]

#   log_driver = "json-file"

#   networks_advanced {
#     name = data.docker_network.storageIntWeb.id

#     aliases = ["DHCPMariaDB"]
#   }

#   volumes {
#     volume_name    = "${var.NextCloudBucket.bucket}"
#     container_path = "/var/lib/mysql"
#     read_only      = false
#   }

#   env = [
#     "MYSQL_ROOT_PASSWORD=password/",
#     "MYSQL_DATABASE=DHCP",
#     "MYSQL_USER=dhcp",
#     "MYSQL_PASSWORD=password"
#   ]

#   # lifecycle {
#   #   ignore_changes = [
#   #     # Ignore changes to tags, e.g. because a management agent
#   #     # updates these based on some ruleset managed elsewhere.
#   #     command,
#   #     cpu_shares,
#   #     dns,
#   #     dns_opts,
#   #     dns_search,
#   #     entrypoint,
#   #     exit_code,
#   #     gateway,
#   #     group_add,
#   #     hostname,
#   #     init,
#   #     ip_address,
#   #     ip_prefix_length,
#   #     ipc_mode,
#   #     links,
#   #     log_opts,
#   #     max_retry_count,
#   #     memory,
#   #     memory_swap,
#   #     network_data,
#   #     network_mode,
#   #     privileged,
#   #     publish_all_ports,
#   #     security_opts,
#   #     shm_size,
#   #     sysctls,
#   #     tmpfs,
#   #     healthcheck,
#   #     labels,
#   #   ]
#   # }
# }

# resource "docker_service" "postgresDatabase" {
#   name = "postgres-database"

#   task_spec {
#     container_spec {
#       image = "postgres:alpine3.14"

#       hostname = "pgdatabase"

#       user   = "root"

#       env = {
#         POSTGRES_PASSWORD = "helloWorld"
#       }

#       mounts {
#         target    = "/var/lib/postgresql/data"
#         source    = "${var.PostgresDatabaseBucket.bucket}"
#         type      = "volume"
#       }

#       stop_signal       = "SIGTERM"
#       stop_grace_period = "10s"
#     }

#     placement {
#       max_replicas = 1
#     }

#     force_update = 0
#     runtime      = "container"
#     networks     = [data.docker_network.coreAuthWeb.id]
#   }

#   mode {
#     replicated {
#       replicas = 1
#     }
#   }

#   update_config {
#     parallelism       = 1
#     delay             = "10s"
#     failure_action    = "pause"
#     monitor           = "5s"
#     max_failure_ratio = "0.1"
#     order             = "start-first"
#   }

#   rollback_config {
#     parallelism       = 2
#     delay             = "5ms"
#     failure_action    = "pause"
#     monitor           = "10h"
#     max_failure_ratio = "0.9"
#     order             = "stop-first"
#   }

#   endpoint_spec {
#     mode = "dnsrr"
#   }
# }