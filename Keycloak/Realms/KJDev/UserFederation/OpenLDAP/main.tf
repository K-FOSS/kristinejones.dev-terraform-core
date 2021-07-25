#
# OpenLDAP User Federation
#
terraform {
  required_providers {
    mysql = {
      source = "winebarrel/mysql"
      version = "1.10.4"
    }

    docker = {
      source = "kreuzwerker/docker"
      version = "2.14.0"
    }

    vault = {
      source = "hashicorp/vault"
      version = "2.22.1"
    }

    keycloak = {
      source  = "mrparkers/keycloak"
      version = "3.2.1"
    }
  }
}

data "vault_generic_secret" "openldap" {
  path = "secret/keycloak/data/OPENLDAP"
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
  bind_credential = data.vault_generic_secret.openldap.data["PASSWORD"]

  connection_timeout = "5s"
  read_timeout       = "10s"

  full_sync_period = 1800
  changed_sync_period = 900

  cache {
    policy = "DEFAULT"
  }
}
