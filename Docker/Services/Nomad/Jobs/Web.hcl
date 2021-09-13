job "web-demo" {
  datacenters = ["core0site1"]

  group "test-web" {
    count = 4

    network {
      mode = "bridge"

      port "http" {}
    }

    service {
      name = "core0web-http"
      port = "http"

      connect {
        sidecar_service {}
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