terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "2.15.0"
    }
  }
}

data "docker_network" "meshSpineNet" {
  name = "meshSpineNet"
}

resource "docker_config" "CortexConfig" {
  name = "cortex-${var.Target}config-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/Cortex.yaml",
      {
        #
        # General
        #
        CORTEX_TARGET = "${var.Target}"

        LOG_LEVEL = "${var.LogLevel}"

        #
        # Clustering
        #

        CONSUL_ADDR = "tasks.ConsulCore"
        CONSUL_PORT = "8500"

        #
        # S3/Minio
        #
        MINIO_ACCESSKEY = "${var.MinioCreds.ACCESS_KEY}",
        MINIO_SECRETKEY = "${var.MinioCreds.SECRET_KEY}",
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_service" "Cortex" {
  name = "Cortex${var.Name}"

  task_spec {
    container_spec {
      image = "cortexproject/cortex:${var.Version}"

      hostname = "Cortex${var.Name}{{.Task.Slot}}"

      args = ["-config.file=/Configs/Config.yaml"]

      env = {
      }

      #
      # Grafana Configuration
      #
      configs {
        config_id   = docker_config.CortexConfig.id
        config_name = docker_config.CortexConfig.name

        file_name   = "/Configs/Config.yaml"
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
    replicated {
      #
      # TODO: Scale this
      #
      replicas = var.Replicas
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