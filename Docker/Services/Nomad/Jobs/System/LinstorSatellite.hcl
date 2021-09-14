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

        extra_hosts = [
          "node0:172.31.245.10",
          "node1:172.31.245.11",
          "node2:172.31.245.12",
          "node3:172.31.245.13"
        ]

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
  }
}