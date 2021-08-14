# output "DHCPDatabaseContainer" {
#   value = docker_service.DHCPDatabase
# }

# output "PostgresDatabaseService" {
#   value = docker_service.postgresDatabase
# }

output "KeycloakService" {
  value = docker_service.Keycloak
}