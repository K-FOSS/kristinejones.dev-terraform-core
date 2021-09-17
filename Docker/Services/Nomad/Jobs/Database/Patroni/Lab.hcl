job "Patroni" {
  datacenters = ["core0site1"]

  group "postgres-database" {
    count = 3

    volume "${Volume.name}" {
      type      = "csi"
      read_only = false
      source    = "${Volume.name}"
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

    task "patroni" {
      driver = "docker"

      user = "101"

      config {
        image = "registry.opensource.zalan.do/acid/spilo-13:2.1-p1"

        command = "/usr/local/bin/patroni"

        network_mode = "bridge"

        hostname = "postgresql$${NOMAD_ALLOC_INDEX}"

        args = ["/local/Patroni.yaml"]

        network_aliases = [
          "postgresql$${NOMAD_ALLOC_INDEX}"
        ]
      }

      service {
        name = "patroni-store"
        port = "psql"

        address_mode = "driver"

        connect {
          sidecar_service {}
        }
      }

      service {
        name = "patroni"
        port = "http"

        address_mode = "driver"

        connect {
          sidecar_service {
          }
        }
      }

      env {
        POSTGRES_PASSWORD = "RANDOM_PASS"
        PGDATA = "/alloc/psql"
        PATRONI_POSTGRESQL_DATA_DIR = "/alloc/psql"
        PATRONI_CONSUL_HOST = "${Patroni.Consul.Hostname}:${Patroni.Consul.Port}"
        PATRONI_CONSUL_URL = "http://${Patroni.Consul.Hostname}:${Patroni.Consul.Port}"
        PATRONI_CONSUL_TOKEN = "${Patroni.Consul.Token}"
        PATRONI_NAME = "postgresql$${NOMAD_ALLOC_INDEX}"
        PATRONI_SCOPE = "site0core1psql"
      }

      volume_mount {
        volume      = "${Volume.name}"
        destination = "/data"
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