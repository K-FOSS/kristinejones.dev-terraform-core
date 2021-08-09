terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "2.22.1"
    }
  }
}

resource "vault_identity_oidc_key" "keycloak_provider_key" {
  name      = "keycloak"
  algorithm = "RS256"
}

resource "vault_jwt_auth_backend" "keycloak" {
  path               = "oidc"
  type               = "oidc"
  default_role       = "default"
  oidc_discovery_url = "https://keycloak.kristianjones.dev/auth/realms/KJDev"
  oidc_client_id  =  "${var.VaultClient.Client.client_id}"
  oidc_client_secret = "${var.VaultClient.Client.client_secret}"

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
  backend        = vault_jwt_auth_backend.keycloak.path
  role_name      = "default"
  role_type      = "oidc"
  token_ttl      = 3600
  token_max_ttl  = 3600

  bound_audiences = ["${var.VaultClient.Client.client_id}"]
  user_claim      = "sub"
  claim_mappings = {
    preferred_username = "username"
    email              = "email"
  }

  allowed_redirect_uris = [
      "https://vault.kristianjones.dev/ui/vault/auth/oidc/oidc/callback",    
      "https://vault.kristianjones.dev/oidc/callback"
  ]
  groups_claim = format("/resource_access/%s/roles", "${var.VaultClient.Client.client_id}")
}

data "vault_policy_document" "reader_policy" {
  rule {
    path         = "/secret/*"
    capabilities = ["list", "read"]
  }
}

resource "vault_policy" "reader_policy" {
  name   = "${var.VaultClient.ReaderRole.name}"
  policy = data.vault_policy_document.reader_policy.hcl
}

data "vault_policy_document" "manager_policy" {
  rule {
    path         = "sys/policies/acl"
    capabilities = ["list"]
  }

  rule {
    path         = "sys/policies/acl/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }

  rule {
    path         = "auth/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }

  rule {
    path         = "sys/auth/*"
    capabilities = ["create", "update", "delete", "sudo"]
  }

  rule {
    path         = "sys/auth"
    capabilities = ["read"]
  }

  rule {
    path         = "secret/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }

  rule {
    path         = "sys/mounts/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }

  rule {
    path         = "sys/mounts"
    capabilities = ["read"]
  }

  rule {
    path         = "database/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }
}

resource "vault_policy" "manager_policy" {
  name   = "${var.VaultClient.ManagementRole.name}"

  policy = data.vault_policy_document.manager_policy.hcl
}

resource "vault_identity_oidc_role" "VaultManagementRole" {
  name = "management"
  key  = vault_identity_oidc_key.keycloak_provider_key.name
}

resource "vault_identity_group" "VaultManagementGroup" {
  name     = vault_identity_oidc_role.VaultManagementRole.name
  type     = "external"

  policies = [
    vault_policy.manager_policy.name
  ]
}

resource "vault_mount" "db" {
  path = "postgres"
  type = "database"
}

resource "vault_database_secret_backend_connection" "postgres" {
  backend       = vault_mount.db.path
  name          = "postgres"
  allowed_roles = ["${vault_identity_oidc_role.VaultManagementRole.name}"]

  postgresql {
    connection_url = "postgres://${var.StolonRole.name}:${var.StolonRole.password}@tasks.HashicorpWeb:5432/postgres?sslmode=disable"
  }
}