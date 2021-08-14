variable "keycloakProtocol" {
  type = string

  default = "https"
}


variable "keycloakHostname" {
  type = string

  default = "keycloak.kristianjones.dev"
}

variable "keycloakPort" {
  type = number

  default = 443
}

variable "keycloakClientID" {
  type = string

  default = "Terraform"
}

variable "keycloakClientSecret" {
  type = string

  default = ""
}