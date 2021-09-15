job "storage-node" {
  datacenters = ["core0site1"]
  type        = "system"

  group "node" {
    constraint {
      operator  = "distinct_hosts"
      value     = "true"
    }

    task "node" {
      driver = "docker"

      config {
        image = "democraticcsi/democratic-csi:latest"

        args = [
          "--csi-version=1.5.0",
          "--csi-name=org.democratic-csi.nfs",
          "--driver-config-file=$${NOMAD_TASK_DIR}/driver-config-file.yaml",
          "--log-level=debug",
          "--csi-mode=node",
          "--server-socket=/csi-data/csi.sock",
          "--server-port=2501",
        ]

        privileged = true
      }

      csi_plugin {
        id        = "truenas"
        type      = "node"
        mount_dir = "/csi-data"
      }

      template {
        destination = "$${NOMAD_TASK_DIR}/driver-config-file.yaml"

        data = <<EOH
${CONFIG}
EOH
      }

      resources {
        cpu    = 124
        memory = 124
      }
    }
  }
}