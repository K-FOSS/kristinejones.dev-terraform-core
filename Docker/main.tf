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

#
# Legacy Vault Secrets
#
 
data "vault_generic_secret" "minio" {
  path = "keycloak/MINIO"
}

data "vault_generic_secret" "pgAuth" {
  path = "keycloak/STOLON"
}

#
# General Settings
#
locals {
  LOG_LEVEL = "WARN"
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
# Grafana Cortex
#
# Website: https://cortexmetrics.io/
# Repo: https://github.com/cortexproject/cortex
#

#
# Cortex Settings
#
locals {
  CORTEX_LOG_LEVEL = "WARN"

  CORTEX_TARGETS = tomap({
    Distributor = {
      target = "distributor"
      replicas = 3
      name = "Distributor"
    },
    Ingester = {
      target = "ingester"
      replicas = 3
      name = "Ingester"
    }, 
    Querier = {
      target = "querier"
      replicas = 3
      name = "Querier"
    }, 
    StoreGateway = {
      target = "store-gateway"
      replicas = 3
      name = "StoreGateway"
    }, 
    Compactor = {
      target = "compactor"
      replicas = 3
      name = "Compactor"
    },
    QueryFrontend = {
      target = "query-frontend"
      replicas = 3
      name = "QueryFrontend"
    },
    AlertManager = {
      target = "alertmanager"
      replicas = 3
      name = "AlertManager"
    },
    Ruler = {
      target = "ruler"
      replicas = 3
      name = "Ruler"
    },
    QueryScheduler = {
      target = "query-scheduler"
      replicas = 3
      name = "QueryScheduler"
    }, 
    Purger = {
      target = "purger"
      replicas = 1
      name = "Purger"
    }
  })
}

# 

data "vault_generic_secret" "MinioCreds" {
  path = "TF_INFRA/MINIO_CREDS"
}

#
# Cortex Sidecars
# 
resource "docker_service" "CortexMemcached" {
  name = "CortexMemcached"

  task_spec {
    container_spec {
      image = "memcached:1.6"

      hostname = "CortexMemcached"

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

module "Cortex" {
  for_each = local.CORTEX_TARGETS

  source = "./Services/Cortex"

  Version = "v1.10.0"

  Target = each.value.target

  Name = each.value.name

  Replicas = each.value.replicas

  LogLevel = "warn"

  Consul = {
    HOSTNAME = "vps1-raw.kristianjones.dev"
    PORT = 8500

    ACL_TOKEN = module.NewConsul.CortexSecretToken.secret_id

    PREFIX = "Cortex"
  }

  MinioCreds = {
    ACCESS_KEY = data.vault_generic_secret.MinioCreds.data["ACCESS_KEY"]
    SECRET_KEY = data.vault_generic_secret.MinioCreds.data["SECRET_KEY"]
  }
}

#
# Grafana Tempo
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

module "Grafana" {
  source = "./Services/Grafana"

  Version = "8.0.3"

  Database = {
    Hostname = "tasks.StolonProxy"

    Username = var.StolonGrafanaRole.name

    Password = var.StolonGrafanaRole.password

    Name = var.StolonGrafanaDB.name
  }

  Consul = {
    Address = "tasks.Consul"
    Token = ""
  }
}

#
# cAdvisor
#
# Repo: https://github.com/google/cadvisor
#

resource "docker_service" "cAdvisor" {
  name = "cAdvisor"

  task_spec {
    container_spec {
      image = "gcr.io/cadvisor/cadvisor:v0.40.0"

      hostname = "cAdvisor"

      env = {
      }

      mounts {
        target    = "/rootfs"
        source    = "/"
        type      = "bind"
        read_only = true
      }

      mounts {
        target    = "/var/run"
        source    = "/var/run"
        type      = "bind"
        read_only = true
      }

      mounts {
        target    = "/sys"
        source    = "/sys"
        type      = "bind"
        read_only = true
      }

      mounts {
        target    = "/var/lib/docker"
        source    = "/var/lib/docker"
        type      = "bind"
        read_only = true
      }

      mounts {
        target    = "/dev/disk"
        source    = "/dev/disk"
        type      = "bind"
        read_only = true
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

    networks     = [data.docker_network.meshSpineNet.id]

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
    mode = "dnsrr"
  }
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

#
# Loki Sidecars
# 
resource "docker_service" "LokiMemcached" {
  name = "LokiMemcached"

  task_spec {
    container_spec {
      image = "memcached:1.6"

      hostname = "LokiMemcached"
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

locals {
  LOKI_LOG_LEVEL = "WARN"

  LOKI_TARGETS = tomap({
    Distributor = {
      target = "distributor"
      replicas = 3
      name = "Distributor"
    },
    Ingester = {
      target = "ingester"
      replicas = 3
      name = "Ingester"
    }, 
    Querier = {
      target = "querier"
      replicas = 3
      name = "Querier"
    },
    IndexGateway = {
      target = "index-gateway"
      replicas = 3
      name = "IndexGateway"
    },
    Compactor = {
      target = "compactor"
      replicas = 3
      name = "Compactor"
    },
    QueryFrontend = {
      target = "query-frontend"
      replicas = 3
      name = "QueryFrontend"
    },
    QueryScheduler = {
      target = "query-scheduler"
      replicas = 3
      name = "QueryScheduler"
    }

    #
    # Todo: Learn about Loki Ruler
    #
    # Ruler = {
    #   target = "ruler"
    #   replicas = 3
    #   name = "Ruler"
    # },
  })
}

module "Loki" {
  for_each = local.CORTEX_TARGETS

  source = "./Services/Loki"

  Version = "2.3.0"

  Target = each.value.target

  Name = each.value.name

  Replicas = each.value.replicas

  LogLevel = "warn"

  Consul = {
    HOSTNAME = "vps1-raw.kristianjones.dev"
    PORT = 8500

    ACL_TOKEN = module.NewConsul.LokiSecretToken.secret_id

    PREFIX = "Cortex"
  }

  Memcached = {
    HOSTNAME = docker_service.LokiMemcached.task_spec[0].container_spec[0].hostname

    PORT = 11211
  }

  MinioCreds = {
    ACCESS_KEY = data.vault_generic_secret.MinioCreds.data["ACCESS_KEY"]
    SECRET_KEY = data.vault_generic_secret.MinioCreds.data["SECRET_KEY"]
  }
}


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
        VERSION = "1.3.11"
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
    templatefile("${path.module}/Configs/Keycloak/Configs/radius.json",
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

#
# JDBC CLI
#

resource "docker_config" "KeycloakJDBCPingCLI" {
  name = "keycloak-jdbcpingcli-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/Keycloak/CLI/JDBC_PING.cli"))

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

      hostname = "Keycloak{{.Task.Slot}}"

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

        JGROUPS_DISCOVERY_PROTOCOL = "JDBC_PING"
        JGROUPS_DISCOVERY_PROPERTIES = "datasource_jndi_name=java:jboss/datasources/KeycloakDS"

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

      healthcheck {
        test     = ["CMD", "curl", "-f", "http://localhost:8080/auth/realms/master"]
        interval = "5s"
        timeout  = "2s"
        retries  = 5

        start_period = "5m"
      }

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

      # 
      # JBDC CLI
      # 
      configs {
        config_id   = docker_config.KeycloakJDBCPingCLI.id
        config_name = docker_config.KeycloakJDBCPingCLI.name

        file_name   = "/opt/jboss/tools/cli/jgroups/discovery/JDBC_PING.cli"
        file_uid = "1000"
        file_mode = 0777
      }
    }

    resources {
      #
      # 1G
      #
      limits {
        memory_bytes = 1073741824
      }

      #
      # 215 MB
      # 
      reservation {
        memory_bytes = 268435456
      }
    }

    force_update = 0
    runtime      = "container"
    networks     = [data.docker_network.AAASpineNet.id, data.docker_network.protectedSpineNet.id, data.docker_network.meshSpineNet.id]
  
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
    delay             = "3m"
    failure_action    = "pause"
    monitor           = "120s"
    max_failure_ratio = "0.2"
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

    force_update = 0
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

resource "random_password" "NetboxRedisPassword" {
  length           = 16
  special          = true
}

resource "docker_service" "NetboxRedis" {
  name = "NetboxRedis"

  task_spec {
    container_spec {
      image = "redis:6-alpine"

      hostname = "NetboxRedis"

      args = ["redis-server", "--requirepass ${random_password.NetboxRedisPassword.result}"]
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

    networks     = [data.docker_network.protectedSpineNet.id]

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


resource "random_password" "NetboxRedisCachePassword" {
  length           = 16
  special          = true
}


resource "docker_service" "NetboxRedisCache" {
  name = "NetboxRedisCache"

  task_spec {
    container_spec {
      image = "redis:6-alpine"

      args = ["redis-server", "--requirepass ${random_password.NetboxRedisCachePassword.result}"]

      hostname = "NetboxRedisCache"
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

    networks     = [data.docker_network.protectedSpineNet.id]

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

        #
        # Redis
        #

        #
        # Redis Core
        #
        REDIS_DATABASE = "0"
        REDIS_HOST = "${docker_service.NetboxRedis.task_spec[0].container_spec[0].hostname}"
        REDIS_PASSWORD = "${random_password.NetboxRedisPassword.result}"
        REDIS_SSL = "false"

        #
        # Redis Cache
        #
        REDIS_CACHE_DATABASE = "1"
        REDIS_CACHE_HOST = "${docker_service.NetboxRedisCache.task_spec[0].container_spec[0].hostname}"
        REDIS_CACHE_PASSWORD = "${random_password.NetboxRedisCachePassword.result}"
        REDIS_CACHE_SSL = "false"

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
    templatefile("${path.module}/Configs/DHCP/DHCP4.jsonc",
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

resource "docker_config" "DHCP6Config" {
  name = "network-dhcp6-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/DHCP/DHCP6.jsonc",
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

resource "docker_config" "DHCPEntryConfig" {
  name = "network-dhcpentryconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/DHCP/entry.sh"))

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

      command = ["/entry.sh"]

      args = []

      hostname = "DHCP{{.Task.Slot}}"

      env = {
        STORK_AGENT_SERVER_TOKEN = "IRH8K2w4e84bPXcU9guLL7CUHnQcHnEf"

        #
        # MISC
        #
        TZ = "America/Winnipeg"
      }

      configs {
        config_id   = docker_config.DHCPConfig.id
        config_name = docker_config.DHCPConfig.name

        file_name   = "/config/DHCP4.json"
      }

      configs {
        config_id   = docker_config.DHCP6Config.id
        config_name = docker_config.DHCP6Config.name

        file_name   = "/config/DHCP6.json"
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

      configs {
        config_id   = docker_config.DHCPEntryConfig.id
        config_name = docker_config.DHCPEntryConfig.name

        file_name   = "/entry.sh"
        file_mode = 0777
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
      publish_mode   = "host"
    }

    #
    # DHCP
    #
    ports {
      name           = "dchp1"
      protocol       = "udp"
      target_port    = "67"
      published_port = "67"
      publish_mode   = "host"
    }

    ports {
      name           = "dhcp2"
      protocol       = "udp"
      target_port    = "68"
      published_port = "68"
      publish_mode   = "host"
    }
  }
}

#
# Business
#

#
# ERPNext
#
# TODO: Deploy ERPNext once Postgress Support rolls out
#
# Tracking https://github.com/frappe/erpnext/issues/24389
#

#
# OpenProject
#

resource "docker_service" "OpenProjectApp" {
  name = "OpenProjectApp"

  task_spec {
    container_spec {
      image = "openproject/community:11"

      hostname = "OpenProjectApp"

      args = ["./docker/prod/web"]

      env = {
        DATABASE_URL = "postgres://${var.StolonOpenProjectRole.name}:${var.StolonOpenProjectRole.password}@tasks.StolonProxy/${var.StolonOpenProjectDB.name}?pool=20&encoding=unicode&reconnect=true"

        RAILS_CACHE_STORE = "memcache"
        OPENPROJECT_CACHE__MEMCACHE__SERVER = "tasks.OpenProjectCache:11211"
        OPENPROJECT_RAILS__RELATIVE__URL__ROOT = ""

        RAILS_MIN_THREADS = "4"
        RAILS_MAX_THREADS = "16"
        USE_PUMA = "true"

        IMAP_ENABLED = "false"
      }
    }

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

  endpoint_spec {
    mode = "dnsrr"
  }
}

resource "docker_service" "OpenProjectWorker" {
  name = "OpenProjectWorker"

  task_spec {
    container_spec {
      image = "openproject/community:11"

      hostname = "OpenProjectWorker"

      args = ["./docker/prod/worker"]

      env = {
        DATABASE_URL = "postgres://${var.StolonOpenProjectRole.name}:${var.StolonOpenProjectRole.password}@tasks.StolonProxy/${var.StolonOpenProjectDB.name}?pool=20&encoding=unicode&reconnect=true"

        RAILS_CACHE_STORE = "memcache"
        OPENPROJECT_CACHE__MEMCACHE__SERVER = "tasks.OpenProjectCache:11211"
        OPENPROJECT_RAILS__RELATIVE__URL__ROOT = ""

        RAILS_MIN_THREADS = "4"
        RAILS_MAX_THREADS = "16"
        USE_PUMA = "true"

        IMAP_ENABLED = "false"
      }
    }

    force_update = 0
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
      replicas = 1
    }
  }

  endpoint_spec {
    mode = "dnsrr"
  }
}

resource "docker_service" "OpenProjectCRON" {
  name = "OpenProjectCRON"

  task_spec {
    container_spec {
      image = "openproject/community:11"

      hostname = "OpenProjectCRON"

      args = ["./docker/prod/cron"]

      env = {
        DATABASE_URL = "postgres://${var.StolonOpenProjectRole.name}:${var.StolonOpenProjectRole.password}@tasks.StolonProxy/${var.StolonOpenProjectDB.name}?pool=20&encoding=unicode&reconnect=true"

        RAILS_CACHE_STORE = "memcache"
        OPENPROJECT_CACHE__MEMCACHE__SERVER = "tasks.OpenProjectCache:11211"
        OPENPROJECT_RAILS__RELATIVE__URL__ROOT = ""

        RAILS_MIN_THREADS = "4"
        RAILS_MAX_THREADS = "16"
        USE_PUMA = "true"

        IMAP_ENABLED = "false"
      }
    }

    force_update = 0
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
      replicas = 1
    }
  }

  endpoint_spec {
    mode = "dnsrr"
  }
}

resource "docker_service" "OpenProjectSeeder" {
  name = "OpenProjectSeeder"

  task_spec {
    container_spec {
      image = "openproject/community:11"

      hostname = "OpenProjectSeeder"

      args = ["./docker/prod/seeder"]

      env = {
        DATABASE_URL = "postgres://${var.StolonOpenProjectRole.name}:${var.StolonOpenProjectRole.password}@tasks.StolonProxy/${var.StolonOpenProjectDB.name}?pool=20&encoding=unicode&reconnect=true"

        RAILS_CACHE_STORE = "memcache"
        OPENPROJECT_CACHE__MEMCACHE__SERVER = "tasks.OpenProjectCache:11211"
        OPENPROJECT_RAILS__RELATIVE__URL__ROOT = ""

        RAILS_MIN_THREADS = "4"
        RAILS_MAX_THREADS = "16"
        USE_PUMA = "true"

        IMAP_ENABLED = "false"
      }
    }

    restart_policy {
      condition    = "on-failure"
      delay        = "3s"
      max_attempts = 4
      window       = "10s"
    }


    force_update = 0
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
      replicas = 1
    }
  }

  endpoint_spec {
    mode = "dnsrr"
  }
}


resource "docker_service" "OpenProjectCache" {
  name = "OpenProjectCache"

  task_spec {
    container_spec {
      image = "memcached"
    }

    resources {
      limits {
        memory_bytes = 16777216
      }
    }

    force_update = 0
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
      replicas = 1
    }
  }

  endpoint_spec {
    mode = "dnsrr"
  }
}

resource "docker_service" "OpenProjectProxy" {
  name = "OpenProjectProxy"

  task_spec {
    container_spec {
      image = "openproject/community:11"

      hostname = "OpenProjectProxy"

      args = ["./docker/prod/proxy"]

      env = {
        APP_HOST = "tasks.OpenProjectApp"

        OPENPROJECT_RAILS__RELATIVE__URL__ROOT = ""

        SERVER_NAME = "openproject.kristianjones.dev"
      }
    }

    force_update = 0
    runtime      = "container"

    networks     = [data.docker_network.meshSpineNet.id,  data.docker_network.protectedSpineNet.id]

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

  endpoint_spec {
    mode = "dnsrr"
  }
}

#
# Wallabag
#
# Website: https://wallabag.org/en/
# Docs: https://doc.wallabag.org/en/

resource "random_password" "WallabagSecret" {
  length           = 20
  special          = true
}


resource "docker_service" "Wallabag" {
  name = "Wallabag"

  task_spec {
    container_spec {
      image = "wallabag/wallabag"

      hostname = "Wallabag"

      #
      # TODO: Finetune this
      #
      # command = ["/usr/sbin/kea-dhcp4"]
      # args = ["-c", "/config/config.json"]

      env = {
        #
        # Instance Config
        #
        SYMFONY__ENV__DOMAIN_NAME = "https://wallabag.kristianjones.dev"

        #
        # Database
        #

        SYMFONY__ENV__DATABASE_DRIVER = "pdo_pgsql"

        SYMFONY__ENV__DATABASE_HOST = "tasks.StolonProxy"
        SYMFONY__ENV__DATABASE_PORT = "5432"

        SYMFONY__ENV__DATABASE_NAME = "${var.StolonWallabagDB.name}"

        SYMFONY__ENV__DATABASE_USER = "${var.StolonWallabagRole.name}"
        SYMFONY__ENV__DATABASE_PASSWORD = "${var.StolonWallabagRole.password}"

        #
        # Postgres ADMIN
        #
        # TODO: Determine if Wallabag User Suffices
        #
        POSTGRES_USER = "${data.vault_generic_secret.pgAuth.data["USERNAME"]}",
        POSTGRES_PASSWORD = "${data.vault_generic_secret.pgAuth.data["PASSWORD"]}"

        #
        # Secrets
        #
        SYMFONY__ENV__SECRET = "${random_password.WallabagSecret.result}"


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

    networks     = [data.docker_network.meshSpineNet.id, data.docker_network.protectedSpineNet.id, docker_network.meshIntSpineNet.id]

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
# RocketChat
#
# Chat Platform
# 

data "docker_network" "rocketChatIntNet" {
  name = "rocketchatIntWeb"
}

resource "docker_service" "RocketChat" {
  name = "RocketChat"

  task_spec {
    container_spec {
      image = "rocketchat/rocket.chat:develop"

      #
      # TODO: Tweak this, Caddy, Prometheus, Loki, etc
      #
      # labels {
      #   label = "foo.bar"
      #   value = "baz"
      # }

      hostname = "RocketChat"

      env = {
        PORT = "8080"

        ROOT_URL = "https://chat.kristianjones.dev"

        MONGO_URL = "mongodb://RocketChatDB1:27017,RocketChatDB2:27017,RocketChatDB3:27017/rocketchat?replicaSet=rs0&w=majority"
        MONGO_OPLOG_URL = "mongodb://RocketChatDB1:27017,RocketChatDB2:27017,RocketChatDB3:27017/local?replicaSet=rs0"
        MOLECULER_LOG_LEVEL = "warn"

        Accounts_OAuth_Custom_Keycloak = "true"
        Accounts_OAuth_Custom_Keycloak_id = "${var.KeycloakModule.KJDevRealm.RocketChatClientModule.OpenIDClient.client_id}"
        Accounts_OAuth_Custom_Keycloak_secret = "${var.KeycloakModule.KJDevRealm.RocketChatClientModule.OpenIDClient.client_secret}"
        Accounts_OAuth_Custom_Keycloak_url = "https://keycloak.kristianjones.dev/auth"
        Accounts_OAuth_Custom_Keycloak_token_path = "/realms/KJDev/protocol/openid-connect/token"
        Accounts_OAuth_Custom_Keycloak_identity_path = "/realms/KJDev/protocol/openid-connect/userinfo"
        Accounts_OAuth_Custom_Keycloak_authorize_path = "/realms/KJDev/protocol/openid-connect/auth"
        Accounts_OAuth_Custom_Keycloak_scope = "openid"
        Accounts_OAuth_Custom_Keycloak_access_token_param = "access_token"
        Accounts_OAuth_Custom_Keycloak_button_label_text = "KJDev"
        Accounts_OAuth_Custom_Keycloak_token_sent_via = "header"
        Accounts_OAuth_Custom_Keycloak_identity_token_sent_via = "default"
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
        target    = "/app/uploads"
        source    = "rocketchat-data"
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

    force_update = 0
    runtime      = "container"
    networks     = [data.docker_network.publicSpineNet.id, data.docker_network.meshSpineNet.id, data.docker_network.rocketChatIntNet.id]
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
# Core Infrastructure
#

#
# Hashicorp
#

#
# Consul
#

locals {
  CONSUL_LOG_LEVEL = "WARN"

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

resource "random_password" "ConsulSecret" {
  length           = 32
  special          = false
}

locals {
  consulSecret = base64encode(random_password.ConsulSecret.result)
}

module "NewConsul" {
  source = "./Services/Consul"

  #
  # Crypto
  #
  Secret = local.consulSecret
 
  #
  # Misc
  #
  Version = "1.10.2"

  LogLevel = ""
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
