job "foo" {
  datacenters = ["core0site1"]
  type        = "service"

  group "foo" {
    task "foo" {
      driver = "docker"
      config {
        image = "redis:3.2"
        labels {
          group = "foo"
        }
      }
    }
  }
}