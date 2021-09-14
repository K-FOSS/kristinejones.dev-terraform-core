job "linstor-satellite" {
  datacenters = ["core0site1"]
  type = "system"

  group "satellite" {
    network {
      mode = "host"
    }

    volume "dev" {
      type = "host"
      source = "dev"
    }

    task "linstor-satellite" {
      driver = "docker"

      config {
        image = "kvaps/linstor-satellite:v1.14.0"

        privileged = true
        network_mode = "host"
      }

      volume_mount {
        volume = "dev"
        destination = "/dev"
      }

      resources {
        cpu    = 500 
        memory = 500
      }
    }

    volume "modules" {
      type = "host"
      source = "modules"
      read_only = true
    }

    volume "kernel-src" {
      type = "host"
      source = "kernel-src"
      read_only = true
    }
  }
}