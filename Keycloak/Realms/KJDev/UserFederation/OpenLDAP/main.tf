#
# OpenLDAP User Federation
#

data "vault_generic_secret" "openldap" {
  path = "secret/keycloak/OPENLDAP"
}

resource "keycloak_ldap_user_federation" "openldap" {
  name     = "openldap"
  realm_id = "${var.realmID}"

  enabled        = true

  import_enabled = true
  trust_email = true

  edit_mode = "WRITABLE"
  sync_registrations = true
  

  username_ldap_attribute = "uid"
  rdn_ldap_attribute      = "uid"
  uuid_ldap_attribute     = "entryUUID"

  user_object_classes = [
    "inetOrgPerson",
    "organizationalPerson",
  ]

  connection_url  = "ldap://tasks.OpenLDAP"
  users_dn        = "ou=People,dc=kristianjones,dc=dev"
  bind_dn         = "cn=admin,dc=kristianjones,dc=dev"
  bind_credential = data.vault_generic_secret.keycloak.data["PASSWORD"]

  connection_timeout = "5s"
  read_timeout       = "10s"

  full_sync_period = 1800
  changed_sync_period = 900

  cache {
    policy = "DEFAULT"
  }
}
