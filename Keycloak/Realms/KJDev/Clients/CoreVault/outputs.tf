output "OpenIDClient" {
  value = keycloak_openid_client.CoreVaultOID
}

output "ManagementRole" {
  value = keycloak_role.CoreVaultManagementRole
}

output "ReaderRole" {
  value = keycloak_role.CoreVaultReaderRole
}