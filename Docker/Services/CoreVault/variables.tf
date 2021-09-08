variable "Consul" {
  type = object({
    HOSTNAME = string
    PORT = number

    ACL_TOKEN = string
    
    PREFIX = string
    SERVICE_NAME = string
  })
  sensitive = true

  description = "Consul Configuration"
}

variable "Version" {
  type = string
  description = "Cortex Version to deploy"
}

variable "Replicas" {
  type = number
  description = "(optional) describe your variable"
}

variable "LogLevel" {
  type = string
  description = "Cortex LogLevel to deploy"
}

