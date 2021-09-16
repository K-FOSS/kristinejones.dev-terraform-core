job "Patroni" {
  datacenters = ["core0site1"]

  group "postgres-database" {
    count = 1

    network {
      mode = "bridge"

      port "psql" {
        static = 5432
      }

      port "http" {
      }
    }

    ephemeral_disk {
      migrate = true
      size    = 500
      sticky  = true
    }

    service {
      name = "patroni-store"
      port = "psql"

      task = "patroni"

      connect {
        sidecar_service {}
      }
    }

    service {
      name = "patroni"
      port = "http"

      task = "patroni"

      connect {
        sidecar_service {
        }
      }
    }

    task "patroni" {
      driver = "docker"

      config {
        image = "registry.opensource.zalan.do/acid/spilo-13:2.1-p1"
      }

      env {
        POSTGRES_PASSWORD = "RANDOM_PASS"
        PGDATA = "/alloc/psql"
        PATRONI_CONSUL_HOST = "${CONFIG.Consul.Hostname}:${CONFIG.Consul.Port}"
        PATRONI_CONSUL_URL = "http://${CONFIG.Consul.Hostname}:${CONFIG.Consul.Port}"
        PATRONI_CONSUL_TOKEN = "${CONFIG.Consul.Token}"
        PATRONI_NAME = "postgresql$${NOMAD_ALLOC_INDEX}"
        PATRONI_SCOPE = "site0core1psql"
      }
    }
  }
}