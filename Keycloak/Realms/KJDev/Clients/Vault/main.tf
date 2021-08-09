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

data "keycloak_realm" "KJDev" {
  realm = "${var.realmName}"
}

resource "random_password" "VaultClientSecret" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "keycloak_openid_client" "VaultClient" {
  realm_id            = data.keycloak_realm.KJDev.id

  #
  # OpenID Client
  #
  client_id           = "Vault"
  client_secret       = random_password.VaultClientSecret.result

  #
  # Keycloak Frontend
  #
  name                = "Vault"
  enabled             = true

  #
  # Keycloak Grant Types
  #
  standard_flow_enabled = true

  # TODO: Figure out how to use this for Terraform
  direct_access_grants_enabled = true

  #
  # Keycloak OpenID Process
  #
  access_type         = "CONFIDENTIAL"
  valid_redirect_uris = [
    "https://vault.kristianjones.dev/*"
  ]

  # This allows us to use FIDO2 Passwordless Auth
  login_theme = "keycloak"

  authentication_flow_binding_overrides {
    browser_id = "${var.FIDO2FlowID}"
  }
}

#########
# Roles #
#########

resource "keycloak_role" "VaultManagementRole" {
  #
  # Keycloak Configuration
  #
  realm_id    = data.keycloak_realm.KJDev.id
  client_id   = keycloak_openid_client.VaultClient.id

  #
  # Role Configuration
  #
  name        = "vault_management"
  description = "Vault Management role"

  #
  # We want Management to have Read Access too
  #
  composite_roles = [
    keycloak_role.VaultReaderRole.id
  ]
}

#
# General Vault Reader Role
#
# TODO: Fine tune roles
#
resource "keycloak_role" "VaultReaderRole" {
  realm_id    = data.keycloak_realm.KJDev.id
  client_id   = keycloak_openid_client.VaultClient.id

  # Friendly Name
  name        = "vault_reader"
  description = "Reader role"
}

#
# SSH Roles
#
resource "keycloak_role" "VaultSSHAdmin" {
  #
  # Keycloak Configuration
  #
  realm_id    = data.keycloak_realm.KJDev.id
  client_id   = keycloak_openid_client.VaultClient.id

  #
  # Role Configuration
  #
  name        = "SSHAdmin"
  description = "Vault SSH Administrator Policy Manager role"

  #
  # TODO: Add VPS Roles & Shit
  #
  # composite_roles = [
  #   keycloak_role.VaultReaderRole.id
  # ]
}


resource "keycloak_openid_user_client_role_protocol_mapper" "VaultUserClientRoleMapper" {
  name           = "vault-role-mapper"

  realm_id    = data.keycloak_realm.KJDev.id
  client_id   = keycloak_openid_client.VaultClient.id

  #
  # TODO: Figure out WTF this does/how/why
  #
  claim_name = format("resource_access.%s.roles", keycloak_openid_client.VaultClient.client_id)                                    
  multivalued = true
}