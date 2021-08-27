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
    Address = string

    Token = string
  })
  sensitive = true

  description = "Database Configuration"
}