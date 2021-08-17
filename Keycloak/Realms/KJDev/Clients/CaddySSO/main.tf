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
  }
}

data "keycloak_realm" "KJDev" {
  realm = var.realmName
}

resource "random_password" "CaddySSOClientSecret" {
  length           = 20
  special          = true
}


resource "keycloak_openid_client" "CaddySSO" {
  realm_id            = data.keycloak_realm.KJDev

  #
  # Client Credentials
  #
  client_id           = "CaddySSO"
  client_secret       = random_password.CaddySSOClientSecret.result

  name                = "Caddy SSO"
  enabled             = true

  standard_flow_enabled = true

  access_type         = "CONFIDENTIAL"
  valid_redirect_uris = [
    "https://auth.kristianjones.dev/auth/oauth2/generic",
    "https://auth.kristianjones.dev/auth/oauth2/generic/authorization-code-callback"
  ]

  login_theme = "keycloak"

  authentication_flow_binding_overrides {
    browser_id = var.FIDO2FlowID
  }
}

#
# TODO: Fine tune Application RBAC
#