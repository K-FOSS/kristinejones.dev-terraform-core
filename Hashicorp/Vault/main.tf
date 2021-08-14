terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "2.22.1"
    }
  }
}

#
# Generic Secrets
#
resource "vault_mount" "Terraform" {
  path        = "TF_INFRA"

  type        = "kv-v2"

  description = "Terraform Consul Sync Core Secrets"
}

resource "vault_generic_secret" "TerraformTest" {
  path = "${vault_mount.Terraform.path}/TMP_TEST"

  data_json = jsonencode({
    testing = "HelloWorld"
    helloworld = "Testing123"
  })
}

#
# This resoucre depends on the variable provided by the Domains module, which depends on the Vault Mount, hopefully this will automatically determine dependencies.
#
# resource "vault_generic_secret" "KJDevDNSSec" {
#   path = "${vault_mount.Terraform.path}/KJDevDNSSEC"

#   data_json = jsonencode(var.KJDevDNSSec)
# }

#
# OpenID
#

#
# Keycloak
# 
resource "vault_identity_oidc_key" "keycloak_provider_key" {
  name      = "keycloak"
  algorithm = "RS256"
}

resource "vault_jwt_auth_backend" "keycloak" {
  path               = "oidc"
  type               = "oidc"

  default_role       = "default"

  oidc_discovery_url = "https://keycloak.kristianjones.dev/auth/realms/KJDev"
  oidc_client_id  = var.KeycloakModule.KJDevRealm.VaultClientModule.OpenIDClient.client_id
  oidc_client_secret = var.KeycloakModule.KJDevRealm.VaultClientModule.OpenIDClient.client_secret

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

  bound_audiences = ["${var.KeycloakModule.KJDevRealm.VaultClientModule.OpenIDClient.client_id}"]
  user_claim      = "sub"
  claim_mappings = {
    preferred_username = "username"
    email              = "email"
  }

  allowed_redirect_uris = [
      "https://vault.kristianjones.dev/ui/vault/auth/oidc/oidc/callback",    
      "https://vault.kristianjones.dev/oidc/callback"
  ]
  groups_claim = format("/resource_access/%s/roles", var.KeycloakModule.KJDevRealm.VaultClientModule.OpenIDClient.client_id)
}

data "vault_policy_document" "reader_policy" {
  rule {
    path         = "/secret/*"
    capabilities = ["list", "read"]
  }
}

resource "vault_policy" "reader_policy" {
  name   = var.KeycloakModule.KJDevRealm.VaultClientModule.ReaderRole.name
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

  #
  # Postgres Database
  # 
  rule {
    path         = "postgres/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }

  #
  # Terraform Generic Secret
  #
  rule {
    path         = "${vault_mount.Terraform.path}/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }
}

#
# Vault Manager
#

resource "vault_policy" "manager_policy" {
  name   = "${var.KeycloakModule.KJDevRealm.VaultClientModule.ManagementRole.name}"

  policy = data.vault_policy_document.manager_policy.hcl
}

resource "vault_identity_oidc_role" "VaultManagementRole" {
  name = "${var.KeycloakModule.KJDevRealm.VaultClientModule.ManagementRole.name}"

  key  = vault_identity_oidc_key.keycloak_provider_key.name
}

resource "vault_identity_group" "VaultManagementGroup" {
  name     = vault_identity_oidc_role.VaultManagementRole.name
  type     = "external"

  policies = [
    vault_policy.manager_policy.name
  ]
}

resource "vault_identity_group_alias" "management_group_alias" {
  name           = var.KeycloakModule.KJDevRealm.VaultClientModule.ManagementRole.name
  mount_accessor = vault_jwt_auth_backend.keycloak.accessor
  canonical_id   = vault_identity_group.VaultManagementGroup.id
}

#
# Postgres Dynamic Database Credentials
#

# resource "vault_mount" "db" {
#   path = "postgres"
#   type = "database"
# }

# resource "vault_database_secret_backend_connection" "postgres" {
#   backend       = vault_mount.db.path
#   name          = "postgres"
#   allowed_roles = ["${vault_identity_oidc_role.VaultManagementRole.name}"]

#   postgresql {
#     connection_url = "postgres://${var.StolonRole.name}:${var.StolonRole.password}@tasks.HashicorpWeb:5432/postgres?sslmode=disable"
#   }
# }

#
# Vault SSH
#

resource "vault_mount" "SSHClientSigner" {
  type = "ssh"

  path = "ssh-client-signer"

  description = "Vault SSH"
}

#
# SSH Client CA
#
resource "vault_ssh_secret_backend_ca" "SSHClientCA" {
  backend = vault_mount.SSHClientSigner.path

  generate_signing_key = true
}

resource "vault_ssh_secret_backend_role" "DemoUser" {
  backend                 = vault_mount.SSHClientSigner.path

  name                    = "DemoUser"

  key_type                = "ca"
  allow_user_certificates = true

  #
  # Key
  #
  algorithm_signer = "rsa-sha2-512"

  #
  # Authorized Users
  #
  allowed_users = "root"
  default_user = "root"

  allowed_extensions = "permit-X11-forwarding,permit-agent-forwarding,permit-port-forwarding,permit-pty,permit-user-rc"

  default_extensions = {
    permit-pty = ""
  }

  #
  # Misc
  #
  ttl = "30m0s"
}


#
# SSH Admin Policy
#
data "vault_policy_document" "SSHAdminPolicy" {
  rule {
    path         = "ssh-client-signer/roles/*"
    capabilities = ["list"]
  }

  rule {
    path         = "ssh-client-signer/sign/${vault_ssh_secret_backend_role.DemoUser.name}"
    capabilities = ["create", "update"]
  }
}

resource "vault_policy" "SSHAdminPolicy" {
  name   = "${var.KeycloakModule.KJDevRealm.VaultClientModule.SSHAdminRole.name}"

  policy = data.vault_policy_document.SSHAdminPolicy.hcl
}

resource "vault_identity_oidc_role" "VaultSSHAdminRole" {
  name = "${var.KeycloakModule.KJDevRealm.VaultClientModule.SSHAdminRole.name}"

  key  = vault_identity_oidc_key.keycloak_provider_key.name
}

resource "vault_identity_group" "VaultSSHAdminGroup" {
  name     = vault_identity_oidc_role.VaultSSHAdminRole.name
  type     = "external"

  policies = [
    vault_policy.SSHAdminPolicy.name
  ]
}

resource "vault_identity_group_alias" "SSHAdminGroup" {
  name           = var.KeycloakModule.KJDevRealm.VaultClientModule.SSHAdminRole.name
  mount_accessor = vault_jwt_auth_backend.keycloak.accessor
  canonical_id   = vault_identity_group.VaultSSHAdminGroup.id
}