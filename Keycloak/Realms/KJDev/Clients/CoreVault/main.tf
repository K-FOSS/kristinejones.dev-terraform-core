terraform {
  required_providers {
    mysql = {
      source = "winebarrel/mysql"
      version = "1.10.4"
    }

    docker = {
      source = "kreuzwerker/docker"
      version = "2.15.0"
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
  realm = var.realmName
}

resource "random_password" "CoreVaultClientID" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "keycloak_openid_client" "CoreVaultOID" {
  realm_id            = data.keycloak_realm.KJDev.id

  #
  # OpenID Client
  #
  client_id           = "CoreVault"
  client_secret       = "${random_password.CoreVaultClientID.result}"

  #
  # Keycloak Frontend
  #
  name                = "CoreVault"
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
    "https://corevault.kristianjones.dev/*"
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

resource "keycloak_role" "CoreVaultManagementRole" {
  #
  # Keycloak Configuration
  #
  realm_id    = data.keycloak_realm.KJDev.id
  client_id   = keycloak_openid_client.CoreVaultOID.id
  
  #
  # Role Configuration
  #
  name        = "management"
  description = "Management role"
  
  #
  # We want Management to have Read Access too
  #
  composite_roles = [
    keycloak_role.CoreVaultReaderRole.id
  ]
}

#
# General Vault Reader Role
#
# TODO: Fine tune roles
#
resource "keycloak_role" "CoreVaultReaderRole" {
  realm_id    = data.keycloak_realm.KJDev.id
  client_id   = keycloak_openid_client.CoreVaultOID.id

  # Friendly Name
  name        = "reader"
  description = "Reader role"
}

resource "keycloak_openid_user_client_role_protocol_mapper" "user_client_role_mapper" {
  name           = "corevault-role-mapper"

  realm_id    = data.keycloak_realm.KJDev.id
  client_id   = keycloak_openid_client.CoreVaultOID.id

  #
  # TODO: Figure out WTF this does/how/why
  #
  claim_name = format("resource_access.%s.roles", keycloak_openid_client.CoreVaultOID.client_id)                                    
  multivalued = true
}