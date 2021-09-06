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

resource "docker_config" "LokiConfig" {
  name = "loki-${var.Target}config-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/Loki.yaml",
      {
        #
        # General
        #
        TARGET = "${var.Target}"

        LOG_LEVEL = "${var.LogLevel}"

        #
        # Clustering
        #

        CONSUL = var.Consul

        MEMCACHED = var.Memcached

        #
        # S3/Minio
        #
        MINIO_ACCESSKEY = "${var.S3.ACCESS_KEY}",
        MINIO_SECRETKEY = "${var.S3.SECRET_KEY}",
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_service" "Loki" {
  name = "Loki${var.Name}"

  task_spec {
    container_spec {
      image = "grafana/loki:${var.Version}"

      hostname = "Loki${var.Name}{{.Task.Slot}}"

      args = ["-config.file=/Configs/Config.yaml"]

      env = {
      }

      #
      # Grafana Configuration
      #
      configs {
        config_id   = docker_config.LokiConfig.id
        config_name = docker_config.LokiConfig.name

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

  endpoint_spec {
    mode = "dnsrr"
  }
}