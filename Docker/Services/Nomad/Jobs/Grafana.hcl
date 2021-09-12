job "test-demo" {

  datacenters = ["core0site1"]

  # The UUID generator from the connect-native demo is used as an example service.
  # The ingress gateway above makes access to the service possible over normal HTTP.
  # For example,
  #
  # $ curl $(dig +short @127.0.0.1 -p 8600 uuid-api.ingress.dc1.consul. ANY):8080
  group "generator" {
    count = 4

    network {
      mode = "host"
      port "api" {}
    }

    service {
      name = "uuid-api"
      port = "api"

      connect {
        native = true
      }
    }

    task "generate" {
      driver = "docker"

      config {
        image        = "hashicorpnomad/uuid-api:v5"
        network_mode = "host"
      }

      env {
        BIND = "0.0.0.0"
        PORT = "${NOMAD_PORT_api}"
      }
    }
  }
}