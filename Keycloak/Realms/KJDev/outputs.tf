output "MinioClient" {
  value = module.MinioClient
}

output "CoreVaultClient" {
  value = module.CoreVaultClient
}

# output "PostgresDatabaseService" {
#   value = docker_service.postgresDatabase
# }