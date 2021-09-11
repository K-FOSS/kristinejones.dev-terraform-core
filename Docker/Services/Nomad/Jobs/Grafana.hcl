job "foo" {
  datacenters = ["core0site1"]
  type        = "service"

  group "foo" {
    task "foo" {
      driver = "docker"
      user = "0"
      config {
        image = "alpine:3.13.6"

        command = "/bin/sh"

        cap_add = ["net_raw"]


        args = ["-c", "ping 172.16.100.1"]
        interactive = true
        tty = true
      }
    }
  }
}