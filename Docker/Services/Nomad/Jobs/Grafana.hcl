job "foo" {
  datacenters = ["core0site1"]
  type        = "service"

  group "foo" {
    task "foo" {
      driver = "docker"
      config {
        image = "alpine:3.13.6"

        command = "/bin/ping"
        args = ["172.16.100.1"]
        interactive = true


        labels {
          group = "foo"
        }
      }
    }
  }
}