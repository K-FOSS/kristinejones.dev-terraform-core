job "Patroni" {
  datacenters = ["core0site1"]

  group "postgres-database" {
    count = 3

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
      port = ["psql"]

      config {
        image = "postgres:13.4-alpine3.14"
      }

      env {
        POSTGRES_PASSWORD = "RANDOM_PASS"
        PGDATA = "/alloc/psql"
      }
    }

    task "patroni" {
      driver = "docker"

      port = ["psql", "http"]

      lifecycle {
        hook = "poststart"
        sidecar = true
      }

      config {
        image = "openstackhelm/patroni:latest-ubuntu_xenial"

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