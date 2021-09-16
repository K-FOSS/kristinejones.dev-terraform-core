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

      user = "101"

      config {
        image = "registry.opensource.zalan.do/acid/spilo-13:2.1-p1"
      }

      env {
        POSTGRES_PASSWORD = "RANDOM_PASS"
        PGDATA = "/alloc/psql"
        SPILO_CONFIGURATION = <<EOF
${CONFIG}
EOF
      }
    }
  }
}