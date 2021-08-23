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

resource "keycloak_realm" "kjdev" {
  realm             = "KJDev"
  enabled           = true

  login_theme = "keycloak"
  account_theme = "keycloak.v2"
  admin_theme = "keycloak"

  access_code_lifespan = "30m"

  browser_flow = "${var.firstRun == true ? "browser" : "Browser-FIDO2"}"

  internationalization {
    supported_locales = [
      "en",
      "de",
      "es",
    ]

    default_locale = "en"
  }

  security_defenses {
    headers {
      x_frame_options                     = "DENY"
      content_security_policy             = "frame-src 'self'; frame-ancestors 'self'; object-src 'none';"
      content_security_policy_report_only = ""
      x_content_type_options              = "nosniff"
      x_robots_tag                        = "none"
      x_xss_protection                    = "1; mode=block"
      strict_transport_security           = "max-age=31536000; includeSubDomains"
    }

    brute_force_detection {
      permanent_lockout                = false
      max_login_failures               = 31
      wait_increment_seconds           = 61
      quick_login_check_milli_seconds  = 1000
      minimum_quick_login_wait_seconds = 120
      max_failure_wait_seconds         = 900
      failure_reset_time_seconds       = 43200
    }
  }

  web_authn_policy {
    relying_party_entity_name = "KJDev Int"
    relying_party_id          = var.keycloakHostname
    signature_algorithms      = [
      "ES256",
      "RS256"]
  }

  web_authn_passwordless_policy {
    relying_party_entity_name = "KJDev Int"
    relying_party_id          = var.keycloakHostname
    signature_algorithms      = [
      "ES256",
      "RS256"]
  }
}

module "FIDO2-Flow" {
  source = "./Authentication/Flows/FIDO2"

  realmName = keycloak_realm.kjdev.realm

  depends_on = [
    keycloak_realm.kjdev
  ]
}

module "OpenLDAP" {
  source = "./UserFederation/OpenLDAP"

  realmName = keycloak_realm.kjdev.realm
  
  depends_on = [
    keycloak_realm.kjdev
  ]
}

#
# Minion S3Core OpenID
#

module "MinioClient" {
  source = "./Clients/Minio"

  realmName = keycloak_realm.kjdev.realm
  FIDO2FlowID = "${module.FIDO2-Flow.FIDO2Flow.id}"

  depends_on = [
    keycloak_realm.kjdev
  ]
}

#
# SSO
#

#
# Legacy Caddy CoreAuth Proxy
#

module "CaddySSO" {
  source = "./Clients/CaddySSO"

  realmName = keycloak_realm.kjdev.realm
  FIDO2FlowID = "${module.FIDO2-Flow.FIDO2Flow.id}"

  depends_on = [
    keycloak_realm.kjdev
  ]
}

#
# TODO: Pomerium
#
 
#
# Hashicorp
#

#
# CoreVault Manager transit for Vault
#

module "CoreVaultClient" {
  source = "./Clients/CoreVault"

  #
  # Keycloak Realm
  #
  realmName = keycloak_realm.kjdev.realm
  FIDO2FlowID = "${module.FIDO2-Flow.FIDO2Flow.id}"

  depends_on = [
    keycloak_realm.kjdev
  ]
}

#
# Primary 3 Vault cluster
#

module "VaultClient" {
  source = "./Clients/Vault"

  realmName = keycloak_realm.kjdev.realm
  FIDO2FlowID = module.FIDO2-Flow.FIDO2Flow.id

  depends_on = [
    keycloak_realm.kjdev
  ]
}

#
# RocketChat
#

module "RocketChatClient" {
  source = "./Clients/RocketChat"

  realmName = keycloak_realm.kjdev.realm
  FIDO2FlowID = module.FIDO2-Flow.FIDO2Flow.id

  depends_on = [
    keycloak_realm.kjdev
  ]
}

# #
# # Users
# #

# module "Users" {
#   source = "./Users"

#   realm = keycloak_realm.kjdev

#   username = "kristianfjones"
# }