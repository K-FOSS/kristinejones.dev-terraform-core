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

resource "docker_config" "CoreVaultConfig" {
  name = "corevault-config-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/CoreVault/Config.hcl",
      {
        LOG_LEVEL = "${var.LogLevel}"

        #
        # Clustering
        #

        CONSUL = var.Consul
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}


resource "docker_service" "CoreVault" {
  name = "CoreVault"

  task_spec {
    container_spec {
      image = "Vault:${var.Version}"

      hostname = "CoreVault{{.Task.Slot}}"

      args = ["server", "-config=/Configs/Config.hcl"]

      env = {
        VAULT_CLUSTER_ADDR = "http://CoreVault{{.Task.Slot}}:8201"

        VAULT_API_ADDR = "http://CoreVault{{.Task.Slot}}:8200"
      }

      #
      # CoreVault Configuration
      #
      configs {
        config_id   = docker_config.CoreVaultConfig.id
        config_name = docker_config.CoreVaultConfig.name

        file_name   = "/Configs/Config.hcl"
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

  endpoint_spec {
    mode = "dnsrr"
  }
}