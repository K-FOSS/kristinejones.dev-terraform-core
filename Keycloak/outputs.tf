output "MinioOIDClient" {
  value = module.kjdev-realm.MinioClient
}

output "KJDevRealm" {
  value = module.kjdev-realm
}

output "KeycloakHostname" {
  value = var.keycloakHostname
}