variable "S3" {
  type = object({
    ACCESS_KEY = string
    SECRET_KEY = string


  })
  sensitive = true

  description = "Minio/S3 Access Credentials"
}

variable "Consul" {
  type = object({
    HOSTNAME = string
    PORT = number

    ACL_TOKEN = string
    PREFIX = string
  })
  sensitive = true

  description = "Consul Configuration"
}

variable "Memcached" {
  type = object({
    HOSTNAME = string
    PORT = number
  })
  sensitive = true

  description = "Memcached Configuration"
}


variable "Target" {
  type = string

}

variable "Name" {
  type = string
  description = "(optional) describe your variable"
}

variable "Replicas" {
  type = number
  description = "(optional) describe your variable"
}

variable "Version" {
  type = string
  description = "Cortex Version to deploy"
}

variable "LogLevel" {
  type = string
  description = "Cortex LogLevel to deploy"
}