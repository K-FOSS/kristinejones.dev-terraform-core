variable "consulHostname" {
  type = string

  default = "consul.kristianjones.dev"
}

variable "consulPort" {
  type = number

  default = 443
}

variable "consulDatacenter" {
  type = string

  default = "dc1"
}

#
# TODO: Add OpenID
#

# variable "consulOIDClientID" {
#   type = string

#   default = "dc1"
# }

# variable "consulOIDClientSecret" {
#   type = string

#   default = "dc1"
# }