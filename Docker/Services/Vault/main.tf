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

resource "docker_config" "VaultConfig" {
  name = "vault-config-${replace(timestamp(), ":", ".")}"
  data = base64encode(
    templatefile("${path.module}/Configs/Vault/Config.hcl",
      {
        LOG_LEVEL = "${var.LogLevel}"

        #
        # Clustering
        #

        CONSUL = var.Consul

        #
        # Database
        #
        DATABASE = var.Database
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}


resource "docker_service" "Vault" {
  name = "Vault"

  task_spec {
    container_spec {
      image = "vault:${var.Version}"

      hostname = "Vault{{.Task.Slot}}"

      args = ["server", "-config=/Configs/Config.hcl"]

      env = {
        VAULT_CLUSTER_ADDR = "http://Vault{{.Task.Slot}}:8201"

        VAULT_API_ADDR = "http://Vault{{.Task.Slot}}:8200"

        VAULT_SEAL_TYPE = "transit"
        VAULT_TOKEN = "${var.VaultTransit.TOKEN.client_token}"
      }

      #
      # Configuration
      #
      configs {
        config_id   = docker_config.VaultConfig.id
        config_name = docker_config.VaultConfig.name

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