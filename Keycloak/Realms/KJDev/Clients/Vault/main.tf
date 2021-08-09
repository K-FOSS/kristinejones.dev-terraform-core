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

resource "random_password" "VaultClientSecret" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "keycloak_openid_client" "VaultClient" {
  realm_id            = "${var.realmID}"

  client_id           = "Vault"
  client_secret       = "${random_password.VaultClientSecret.result}"

  name                = "Vault"
  enabled             = true

  standard_flow_enabled = true
  direct_access_grants_enabled = true

  access_type         = "CONFIDENTIAL"
  valid_redirect_uris = [
    "https://vault.kristianjones.dev/*"
  ]

  login_theme = "keycloak"

  authentication_flow_binding_overrides {
    browser_id = "${var.FIDO2FlowID}"
  }
}

resource "keycloak_role" "VaultManagementRole" {
  realm_id    = "${var.realmID}"
  client_id   = keycloak_openid_client.VaultClient.id
  name        = "vault_management"
  description = "Vault Management role"
  composite_roles = [
    keycloak_role.VaultReaderRole.id
  ]
}

resource "keycloak_role" "VaultReaderRole" {
  realm_id    = "${var.realmID}"
  client_id   = keycloak_openid_client.VaultClient.id
  name        = "vault_reader"
  description = "Reader role"
}

resource "keycloak_openid_user_client_role_protocol_mapper" "VaultUserClientRoleMapper" {
  name           = "vault-role-mapper"

  realm_id    = "${var.realmID}"
  client_id   = keycloak_openid_client.VaultClient.id

  claim_name = format("resource_access.%s.roles", keycloak_openid_client.VaultClient.client_id)                                    
  multivalued = true
}