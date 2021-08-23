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

resource "random_password" "RocketChatClientSecret" {
  length           = 16
  special          = true
}

resource "keycloak_openid_client" "RocketChatClient" {
  realm_id            = data.keycloak_realm.KJDev.id

  #
  # OpenID Client
  #
  client_id           = "RocketChat"
  client_secret       = random_password.RocketChatClientSecret.result

  #
  # Keycloak Frontend
  #
  name                = "RocketChat"
  enabled             = true

  #
  # Keycloak Grant Types
  #
  standard_flow_enabled = true

  # TODO: Figure out how to use this for Programtic RocketChat
  direct_access_grants_enabled = true

  #
  # Keycloak OpenID Process
  #
  access_type         = "CONFIDENTIAL"
  valid_redirect_uris = [
    "https://chat.kristianjones.dev/*"
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

#
# TODO: Roles & Shit
#


# resource "keycloak_role" "AdminRole" {
#   #
#   # Keycloak Configuration
#   #
#   realm_id    = data.keycloak_realm.KJDev.id
#   client_id   = keycloak_openid_client.RocketChatClient.id

#   #
#   # Role Configuration
#   #
#   name        = "chat_admin"
#   description = "RocketChat Administrator"

#   #
#   # We want Management to have Read Access too
#   #
#   composite_roles = [
#     keycloak_role.StaffRole.id
#   ]
# }

# #
# # General Vault Reader Role
# #
# # TODO: Fine tune roles
# #
# resource "keycloak_role" "StaffRole" {
#   realm_id    = data.keycloak_realm.KJDev.id
#   client_id   = keycloak_openid_client.RocketChatClient.id

#   # Friendly Name
#   name        = "chat_staff"
#   description = "RocketChat Staff"
# }


# resource "keycloak_openid_user_client_role_protocol_mapper" "RocketChatUserClientRoleMapper" {
#   name           = "rocketchat-role-mapper"

#   realm_id    = data.keycloak_realm.KJDev.id
#   client_id   = keycloak_openid_client.RocketChatClient.id

#   #
#   # TODO: Figure out WTF this does/how/why
#   #
#   claim_name = format("resource_access.%s.roles", keycloak_openid_client.RocketChatClient.client_id)                                    
#   multivalued = true
# }