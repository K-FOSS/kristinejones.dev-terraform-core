job "database-demo" {
  datacenters = ["core0site1"]

  group "database-store" {
    count = 1

    volume "test4-vol" {
      type      = "csi"
      read_only = false
      source    = "test4-vol"
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    network {
      mode = "bridge"

      port "psql" {
        static = 5432
      }

      port "http" {
      }
    }

    service {
      name = "databasedemo-store"
      port = "psql"

      task = "database-store1"

      connect {
        sidecar_service {}
      }
    }

    task "database-store1" {
      driver = "docker"

      config {
        image = "postgres:13.4-alpine3.14"
      }

      env {
        POSTGRES_PASSWORD = "RANDOM_PASS"
        PGDATA = "/dbdata"
      }

      volume_mount {
        volume      = "test4-vol"
        destination = "/dbdata"
      }
    }
  }

  group "database-proxy" {
    count = 3

    network {
      mode = "bridge"

      port "http" {}

      port "psql" {}
    }

    service {
      name = "database-demo-webhttp"
      port = "http"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "databasedemo-web"
              local_bind_port  = 8080
            }
          }
        }
      }
    }

    service {
      name = "database-demo-webpsql"
      port = "psql"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "databasedemo-store"
              local_bind_port  = 5432
            }
          }
        }
      }
    }

    task "caddytest" {
      driver = "docker"

      config {
        image        = "kristianfjones/caddy-core-docker:vps1"
      
        args = ["caddy", "run", "--config", "/local/caddyfile.json"]
      }

      template {
        data = <<EOF
${CADDYFILE}
EOF

        destination = "local/caddyfile.json"
      }
    }
  }
}