variable "Version" {
  type = string
  description = "Grafana Version to deploy (Docker Tag)"
}

variable "Database" {
  type = object({
    Hostname = string

    Name = string

    Username = string
    Password = string
  })
  sensitive = true

  description = "Database Configuration"
}

variable "Consul" {
  type = object({
    Hostname = string
    Port = number
    GRPCPort = number

    Token = string

    ServiceName = string
  })
  sensitive = true

  description = "Consul Configuration"
}