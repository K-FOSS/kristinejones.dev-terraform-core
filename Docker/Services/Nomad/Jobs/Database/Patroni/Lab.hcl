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
      mode = "cni/spine0"

      port "psql" {
        static = 5432
      }

      port "http" {
      }
    }

    service {
      name = "patroni-store"
      port = "psql"

      task = "patroni"

      tags = ["$${NOMAD_ALLOC_INDEX}"]

      meta {
        id = "$${NOMAD_ALLOC_INDEX}"
      }

      address_mode = "alloc"
    }

    service {
      name = "patroni"
      port = "http"

      task = "patroni"

      tags = ["$${NOMAD_ALLOC_INDEX}"]

      meta {
        id = "$${NOMAD_ALLOC_INDEX}"
      }

      address_mode = "alloc"
    }

    task "patroni" {
      driver = "docker"

      user = "101"

      config {
        image = "registry.opensource.zalan.do/acid/spilo-13:2.1-p1"

        ports = ["psql", "http"]

        command = "/usr/local/bin/patroni"

        args = ["/local/Patroni.yaml"]
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