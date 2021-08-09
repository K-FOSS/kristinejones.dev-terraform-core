terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "2.22.1"
    }
  }
}

data "vault_generic_secret" "corevault" {
  path = "keycloak/CORE_VAULT"
}


provider "vault" {
  alias = "corevault"

  # It is strongly recommended to configure this provider through the
  # environment variables described above, so that each user can have
  # separate credentials set in the environment.
  #
  # This will default to using $VAULT_ADDR
  # But can be set explicitly
  address = "${var.VaultURL}"

  token = "${data.vault_generic_secret.corevault.data["TOKEN"]}"
}

resource "vault_identity_oidc_key" "keycloak_provider_key" {
  provider = vault.corevault
  
  name      = "keycloak"
  algorithm = "RS256"
}

resource "vault_jwt_auth_backend" "keycloak" {
  provider = vault.corevault
  path               = "oidc"
  type               = "oidc"
  default_role       = "default"
  oidc_discovery_url = "https://keycloak.kristianjones.dev/auth/realms/KJDev"
  oidc_client_id  =  "${var.OpenIDClientID}"
  oidc_client_secret = "${var.OpenIDClientSecret}"

  tune {
    audit_non_hmac_request_keys  = []
    audit_non_hmac_response_keys = []
    default_lease_ttl            = "1h"
    listing_visibility           = "unauth"
    max_lease_ttl                = "1h"
    passthrough_request_headers  = []
    token_type                   = "default-service"
  }
}

resource "vault_jwt_auth_backend_role" "default" {
  provider = vault.corevault
  backend        = vault_jwt_auth_backend.keycloak.path
  role_name      = "default"
  role_type      = "oidc"
  token_ttl      = 3600
  token_max_ttl  = 3600

  bound_audiences = ["${var.OpenIDClientID}"]
  user_claim      = "sub"
  claim_mappings = {
    preferred_username = "username"
    email              = "email"
  }

  allowed_redirect_uris = [
      "https://corevault.kristianjones.dev/ui/vault/auth/oidc/oidc/callback",    
      "https://corevault.kristianjones.devS/oidc/callback"
  ]
  groups_claim = format("/resource_access/%s/roles", "${var.OpenIDClientID}")
}

data "vault_policy_document" "reader_policy" {
  provider = vault.corevault
  rule {
    path         = "/secret/*"
    capabilities = ["list", "read"]
  }
}

resource "vault_policy" "reader_policy" {
  provider = vault.corevault
  name   = "reader"
  policy = data.vault_policy_document.reader_policy.hcl
}
data "vault_policy_document" "manager_policy" {
  provider = vault.corevault
  rule {
    path         = "/secret/*"
    capabilities = ["create", "update", "delete"]
  }
}

resource "vault_policy" "manager_policy" {
  provider = vault.corevault
  name   = "management"
  policy = data.vault_policy_document.manager_policy.hcl
}