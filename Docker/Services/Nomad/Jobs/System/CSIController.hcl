job "storage-controller" {
  datacenters = ["core0site1"]
  type        = "service"



  group "controller" {
    constraint {
      operator  = "distinct_hosts"
      value     = "true"
    }
  
    network {
      mode = "bridge"

      port "grpc" {
        static = 2500
        to     = 2500
      }
    }

    task "controller" {
      driver = "docker"

      config {
        image = "democraticcsi/democratic-csi:latest"
        ports = ["grpc"]

        args = [
          "--csi-version=1.5.0",
          "--csi-name=org.democratic-csi.nfs",
          "--driver-config-file=$${NOMAD_TASK_DIR}/driver-config-file.yaml",
          "--log-level=debug",
          "--csi-mode=controller",
          "--server-socket=/csi-data/csi.sock",
          "--server-address=0.0.0.0",
          "--server-port=2500",
        ]

        privileged = true
      }

      csi_plugin {
        id        = "truenas"
        type      = "controller"
        mount_dir = "/csi-data"
      }

      template {
        destination = "$${NOMAD_TASK_DIR}/driver-config-file.yaml"

        data = <<EOH
${CONFIG}
EOH
      }

      resources {
        cpu    = 30
        memory = 200
      }
    }
  }
}