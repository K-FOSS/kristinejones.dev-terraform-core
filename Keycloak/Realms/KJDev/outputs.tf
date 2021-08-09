output "MinioClient" {
  value = module.MinioClient
}

output "CoreVaultClient" {
  value = module.CoreVaultClient.CoreVaultClient
}

output "VaultClientModule" {
  value = module.VaultClient
}

# output "PostgresDatabaseService" {
#   value = docker_service.postgresDatabase
# }