output "OpenIDClient" {
  value = keycloak_openid_client.VaultClient
}

output "ManagementRole" {
  value = keycloak_role.VaultManagementRole
}

output "ReaderRole" {
  value = keycloak_role.VaultReaderRole
}