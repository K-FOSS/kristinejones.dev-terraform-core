terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "2.14.0"
    }

    minio = {
      source  = "aminueza/minio"
      version = "1.2.0"
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

resource "docker_plugin" "s3core-storage" {
  name                  = "rexray/s3fs"
  alias                 = "s3core-storage"
  enabled               = true
  grant_all_permissions = true
  enable_timeout        = 300

  force_destroy         = false
  force_disable         = false

  env = [
    "S3FS_OPTIONS=allow_other,use_path_request_style,nonempty,url=${var.minioURL}",
    "S3FS_ENDPOINT=${var.minioURL}",
    "S3FS_ACCESSKEY=${data.vault_generic_secret.minio.data["ACCESS_KEY"]}",
    "S3FS_SECRETKEY=${data.vault_generic_secret.minio.data["SECRET_KEY"]}"
  ]

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      env,
    ]
  }
}

data "docker_network" "storageIntWeb" {
  name = "storageIntWeb"
}

data "docker_network" "coreAuthWeb" {
  name = "authWeb"
}

resource "docker_image" "mariadb" {
  provider = docker
  name         = "kristianfjones/mariadb:vps1-core"
  keep_locally = true
}

# resource "docker_service" "DHCPDatabase" {
#   name = "DHCPDatabase"

#   task_spec {
#     container_spec {
#       image = "mariadb:10"

#       hostname = "DHCPDatabase"

#       env = {
#         MYSQL_ROOT_PASSWORD = "password"
#         MYSQL_DATABASE = "DHCP"
#         MYSQL_USER = "dhcp"
#         MYSQL_PASSWORD = "password"
#         MYSQL_ROOT_HOST = "DHCPDatabase"
#       }

#       mounts {
#         target    = "/var/lib/mysql"
#         source    = "dhcp-database"
#         type      = "volume"
#       }
#     }

#     networks = ["${data.docker_network.storageIntWeb.id}"]
#   }
# }

resource "docker_container" "DHCPDatabase" {
  name    = "dhcpDatabase"
  image   = "mariadb:10"

  cpu_shares      = 4
  memory = 256

  dns        = ["1.1.1.1", "1.0.0.1"]

  log_driver = "json-file"

  networks_advanced {
    name = data.docker_network.storageIntWeb.id

    aliases = ["DHCPMariaDB"]
  }

  volumes {
    volume_name    = "${var.NextCloudBucket.bucket}"
    container_path = "/var/lib/mysql"
    read_only      = false
  }

  env = [
    "MYSQL_ROOT_PASSWORD=password/",
    "MYSQL_DATABASE=DHCP",
    "MYSQL_USER=dhcp",
    "MYSQL_PASSWORD=password"
  ]

  # lifecycle {
  #   ignore_changes = [
  #     # Ignore changes to tags, e.g. because a management agent
  #     # updates these based on some ruleset managed elsewhere.
  #     command,
  #     cpu_shares,
  #     dns,
  #     dns_opts,
  #     dns_search,
  #     entrypoint,
  #     exit_code,
  #     gateway,
  #     group_add,
  #     hostname,
  #     init,
  #     ip_address,
  #     ip_prefix_length,
  #     ipc_mode,
  #     links,
  #     log_opts,
  #     max_retry_count,
  #     memory,
  #     memory_swap,
  #     network_data,
  #     network_mode,
  #     privileged,
  #     publish_all_ports,
  #     security_opts,
  #     shm_size,
  #     sysctls,
  #     tmpfs,
  #     healthcheck,
  #     labels,
  #   ]
  # }
}

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