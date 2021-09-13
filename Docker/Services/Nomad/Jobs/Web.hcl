job "web-demo" {
  datacenters = ["core0site1"]

  group "static-web2" {
    count = 1

    network {
      mode = "bridge"

      port "http" {}
    }

    service {
      name = "staticweb-http"
      port = "http"

      connect {
        sidecar_service {}
      }
    }

    task "staticweb1" {
      driver = "docker"

      config {
        image        = "kristianfjones/caddy-core-docker:vps1"
      
        args = ["caddy", "run", "--config", "/local/caddyfile.json"]
      }

      template {
        data = <<EOF
${STATICWEB_CADDYFILE}
EOF

        destination = "local/caddyfile.json"
      }
    }
  }

  group "sorter-web" {
    count = 3

    network {
      mode = "bridge"

      port "http" {}
    }

    service {
      name = "core0web-http"
      port = "http"

      connect {
        sidecar_service {
          proxy {
            local_service_address = "127.0.0.5"

            upstreams {
              destination_name = "staticweb-http"
              local_bind_port  = 8080
              local_bind_address = "127.0.0.5"
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