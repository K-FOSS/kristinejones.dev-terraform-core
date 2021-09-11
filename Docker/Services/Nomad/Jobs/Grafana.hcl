job "foo" {
  datacenters = ["core0site1"]
  type        = "service"

  group "foo" {
    task "foo" {
      driver = "docker"
      config {
        command = "ping"
        args    = ["172.16.100.1"]
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
  }
}