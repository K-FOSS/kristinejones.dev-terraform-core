output "VaultRole" {
  value = postgresql_role.vault
}

output "KeycloakRole" {
  value = postgresql_role.KeycloakUser
}

output "KeycloakDB" {
  value = postgresql_database.KeycloakDB
}

# output "BitwardenRole" {
#   value = postgresql_role.BitwardenUser
# }

# output "BitwardenDB" {
#   value = postgresql_database.BitwardenDB
# }
