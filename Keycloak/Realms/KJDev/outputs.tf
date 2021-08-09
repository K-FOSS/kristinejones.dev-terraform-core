output "MinioClient" {
  value = module.MinioClient
}

output "CoreVaultClient" {
  value = module.CoreVaultClient.CoreVaultClient
}

# output "PostgresDatabaseService" {
#   value = docker_service.postgresDatabase
# }