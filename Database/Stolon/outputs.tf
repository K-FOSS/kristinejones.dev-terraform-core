output "VaultRole" {
  value = postgresql_role.vault
}

output "KeycloakRole" {
  value = postgresql_role.KeycloakUser
}

output "KeycloakDB" {
  value = postgresql_database.KeycloakDB
}
