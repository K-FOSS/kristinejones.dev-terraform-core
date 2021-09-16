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

      task = "database"

      connect {
        sidecar_service {}
      }
    }

    task "database" {
      driver = "docker"

      config {
        image = "postgres:13.4-alpine3.14"
      }

      env {
        POSTGRES_PASSWORD = "RANDOM_PASS"
        PGDATA = "/alloc/psql"
      }
    }

    service {
      name = "patroni"
      port = "http"

      task = "patroni"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "patroni-store"
              local_bind_port  = 5432
            }
          }
        }
      }
    }

    task "patroni" {
      driver = "docker"

      lifecycle {
        hook = "poststart"
        sidecar = true
      }

      config {
        image = "registry.opensource.zalan.do/acid/spilo-13:2.1-p1"

        command = "/usr/local/bin/patroni"

        args = ["/local/Patroni.yaml"]
      }

      env {
        POSTGRES_PASSWORD = "RANDOM_PASS"
        PGDATA = "/alloc/psql"
      }

      template {
        data = <<EOF
${CONFIG}
EOF

        destination = "local/Patroni.yaml"
      }
    }
  }
}