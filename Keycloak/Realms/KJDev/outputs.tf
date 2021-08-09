output "MinioClient" {
  value = module.MinioClient
}

output "CoreVaultClientModule" {
  value = module.CoreVaultClient
}

output "VaultClientModule" {
  value = module.VaultClient
}

# output "PostgresDatabaseService" {
#   value = docker_service.postgresDatabase
# }