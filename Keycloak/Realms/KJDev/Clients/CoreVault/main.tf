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

    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
  }
}

resource "random_password" "corevault_secret" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "keycloak_openid_client" "corevault-oid" {
  realm_id            = "${var.realmID}"

  client_id           = "CoreVault"
  client_secret       = "${random_password.corevault_secret}"

  name                = "CoreVault"
  enabled             = true

  standard_flow_enabled = true
  direct_access_grants_enabled = true

  access_type         = "CONFIDENTIAL"
  valid_redirect_uris = [
    "https://corevault.kristianjones.dev/*"
  ]

  login_theme = "keycloak"

  authentication_flow_binding_overrides {
    browser_id = "${var.FIDO2FlowID}"
  }
}

resource "keycloak_role" "management_role" {
  realm_id    = "${var.realmID}"
  client_id   = keycloak_openid_client.corevault-oid.id
  name        = "management"
  description = "Management role"
  composite_roles = [
    keycloak_role.reader_role.id
  ]
}

resource "keycloak_role" "reader_role" {
  realm_id    = "${var.realmID}"
  client_id   = keycloak_openid_client.corevault-oid.id
  name        = "reader"
  description = "Reader role"
}

resource "keycloak_openid_user_client_role_protocol_mapper" "user_client_role_mapper" {
  name           = "corevault-role-mapper"

  realm_id    = "${var.realmID}"
  client_id   = keycloak_openid_client.corevault-oid.id

  claim_name = format("resource_access.%s.roles", keycloak_openid_client.corevault-oid.client_id)                                    
  multivalued = true
}