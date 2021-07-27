output "DHCPDatabaseContainer" {
  value = docker_container.DHCPDatabase
}

output "PostgresDatabaseService" {
  value = docker_service.postgresDatabase
}