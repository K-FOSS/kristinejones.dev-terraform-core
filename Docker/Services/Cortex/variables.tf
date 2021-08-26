variable "MinioCreds" {
  type = object({
    ACCESS_KEY = string
    SECRET_KEY = string
  })
  sensitive = true

  description = "Minio/S3 Access Credentials"
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