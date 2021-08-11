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

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

#
# Networks
#
data "docker_network" "publicSpineNet" {
  name = "publicSpineNet"
}

data "docker_network" "AAASpineNet" {
  name = "AAASpineNet"
}

data "docker_network" "protectedSpineNet" {
  name = "protectedSpineNet"
}

data "docker_network" "meshSpineNet" {
  name = "meshSpineNet"
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

resource "docker_service" "AlpineScriptTest1" {
  name = "AlpineScriptTest"

  task_spec {
    container_spec {
      image = "alpine:3.14.1"

      #
      # TODO: Tweak this, Caddy, Prometheus, Loki, etc
      #
      # labels {
      #   label = "foo.bar"
      #   value = "baz"
      # }

      command = ["/entry.sh"]
      args = []

      hostname = "AlpineScriptTest{{.Task.Slot}}"

      env = {
        TEST = "HELLO{{.Task.Slot}}"
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


      # dns_config {
      #   nameservers = ["1.1.1.1", "1.0.0.1"]
      #   search      = ["kristianjones.dev"]
      #   options     = ["timeout:3"]
      # }

      configs {
        config_id   = docker_config.AlpineScriptTest1Entry.id
        config_name = docker_config.AlpineScriptTest1Entry.name

        file_name   = "/entry.sh"
        file_uid = "1000"
        file_mode = 7777
      }

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
# TFTP
#

resource "docker_volume" "TFTPData" {
  name = "test"
}

resource "docker_service" "TFTPd" {
  name = "TFTPd"

  task_spec {
    container_spec {
      image = "kristianfoss/programs-tftpd:tftpd-stable-scratch"

      args = ["-E", "0.0.0.0", "8069", "tftpd", "-u", "user", "-c", "/data"]

      user   = "1000"

      mounts {
        target    = "/data"
        source    = var.TFTPBucket.bucket
        type      = "volume"

        volume_options {
          driver_name = "s3core-storage"
        }
      }
    }

    force_update = 0
    runtime      = "container"
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
    ports {
      name           = "tftp"
      protocol       = "udp"
      target_port    = "8069"
      published_port = "69"
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