variable "Consul" {
  type = object({
    Hostname = string
    Port = number

    Token = string

    Prefix = string
    ServiceName = object({
      Server = string

      Client = string
    })
  })
  sensitive = true

  description = "Consul Configuration"
}

#
# TODO: Get Hashicorp Vault connected to Nomad
#

# variable "Vault" {
#   type = object({
#     Hostname = string
#     Port = number

#     Token = string

#     Prefix = string
#     ServiceName = string
#   })
#   sensitive = true

#   description = "Consul Configuration"
# }


#
# Service Configs
# 

variable "Version" {
  type = string
}

variable "Replicas" {
  type = number
  description = "(optional) describe your variable"
}

#
# Misc
#

variable "LogLevel" {
  type = string

  #
  # TODO: Get Validation of this
  #  
}