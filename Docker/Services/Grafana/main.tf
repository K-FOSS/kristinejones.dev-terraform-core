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

resource "docker_config" "GrafanaConfig" {
  name = "grafana-grafanaini-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/Grafana/Grafana.ini",
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

resource "docker_secret" "GrafanaDatabaseName" {
  name = "grafana-dbname-${replace(timestamp(), ":", ".")}"
  data = base64encode(var.Database.Name)

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_secret" "GrafanaDatabaseUsername" {
  name = "grafana-database-username-${replace(timestamp(), ":", ".")}"
  data = base64encode(var.Database.Username)

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_secret" "GrafanaDatabasePassword" {
  name = "grafana-database-password-${replace(timestamp(), ":", ".")}"
  data = base64encode(var.Database.Password)

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_service" "Grafana" {
  name = "Grafana"

  task_spec {
    container_spec {
      image = "grafana/grafana:${var.Version}"

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
        config_id   = docker_config.GrafanaConfig.id
        config_name = docker_config.GrafanaConfig.name

        file_name   = "/etc/grafana/grafana.ini"
      }

      #
      # Grafana Database
      #
      secrets {
        secret_id   = docker_secret.GrafanaDatabaseName.id
        secret_name = docker_secret.GrafanaDatabaseName.name

        file_name   = "/run/secrets/DB_NAME"
      }

      secrets {
        secret_id   = docker_secret.GrafanaDatabaseUsername.id
        secret_name = docker_secret.GrafanaDatabaseUsername.name

        file_name   = "/run/secrets/DB_USER"
      }

      secrets {
        secret_id   = docker_secret.GrafanaDatabasePassword.id
        secret_name = docker_secret.GrafanaDatabasePassword.name

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
# Grafana Consul SideCar Service
#
resource "docker_config" "GrafanaSidecarEntryScriptConfig" {
  name = "grafanasidecar-entryconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/Sidecar/start.sh"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_config" "GrafanaSidecarServiceConfig" {
  name = "grafanasidecar-serviceconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/Sidecar/Grafana.hcl"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_config" "GrafanaSidecarCentralConfig" {
  name = "grafanasidecar-centralconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/Sidecar/GrafanaDefaults.hcl"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}



resource "docker_service" "GrafanaSidecar" {
  name = "GrafanaSidecar"

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

      hostname = "GrafanaSidecar{{.Task.Slot}}"

      env = {
        CONSUL_BIND_INTERFACE = "eth0"
        CONSUL_CLIENT_INTERFACE = "eth0"
        CONSUL_HTTP_ADDR = "tasks.Consul:8500"
        CONSUL_GRPC_ADDR = "tasks.Consul:8502"
        CONSUL_HTTP_TOKEN = "e95b599e-166e-7d80-08ad-aee76e7ddf19"

        SERVICE_HOST = "GrafanaSidecar{{.Task.Slot}}"

        SERVICE_NAME = "GrafanaGateway"
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
        config_id   = docker_config.GrafanaSidecarEntryScriptConfig.id
        config_name = docker_config.GrafanaSidecarEntryScriptConfig.name

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
    mode = "dnsrr"
  }
}