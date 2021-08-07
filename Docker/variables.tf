# variable "NextCloudBucket" {
#   description = "NextCloudBucket"
# }

# variable "PostgresDatabaseBucket" {
#   description = "Postgres SQL Root Database Minio Bucket"
# }

variable "minioURL" {
  type = string

  default = "https://s3core.kristianjones.dev:443"
}