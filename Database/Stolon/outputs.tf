#
# Vault
#

output "VaultRole" {
  value = postgresql_role.vault
}

#
# Keycloak
#
output "KeycloakRole" {
  value = postgresql_role.KeycloakUser
}

output "KeycloakDB" {
  value = postgresql_database.KeycloakDB
}

#
# Bitwarden
#
output "BitwardenRole" {
  value = postgresql_role.BitwardenUser
}

output "BitwardenDB" {
  value = postgresql_database.BitwardenDB
}

#
# OpenNMS
#
output "OpenNMSRole" {
  value = postgresql_role.OpenNMSUser
}

output "OpenNMSDB" {
  value = postgresql_database.OpenNMSDB
}
