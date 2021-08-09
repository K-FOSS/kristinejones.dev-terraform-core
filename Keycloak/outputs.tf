output "MinioOIDClient" {
  value = module.kjdev-realm.MinioClient
}

output "VaultOIDClient" {
  value = module.kjdev-realm.CoreVaultClient
}

output "KJDevRealm" {
  value = module.kjdev-realm
}

output "KeycloakHostname" {
  value = var.keycloakHostname
}