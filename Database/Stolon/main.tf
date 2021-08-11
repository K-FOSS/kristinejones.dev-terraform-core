terraform {
  required_providers {
    postgresql = {
      source = "cyrilgdn/postgresql"
      version = "1.13.0"
    }

    vault = {
      source = "hashicorp/vault"
      version = "2.22.1"
    }

    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
  }
}

data "vault_generic_secret" "pgAuth" {
  path = "keycloak/STOLON"
}

provider "postgresql" {
  host            = "${var.postgresHost}"
  port            = 5432
  username        = "${data.vault_generic_secret.pgAuth.data["USERNAME"]}"
  password        = "${data.vault_generic_secret.pgAuth.data["PASSWORD"]}"

  sslmode = "disable"
}

resource "postgresql_database" "hashicorpBoundary" {
  name     = "boundary1"
}

#
# Hashicorp Vault Postgres Secret Engine
#
resource "random_password" "StolonVaultPassword" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "postgresql_role" "vault" {
  name     = "vault"

  login    = true
  password = random_password.StolonVaultPassword.result

  superuser = true
  create_database = true
  create_role = true
}

#
# Keycloak Database
#
resource "random_password" "StolonKeycloakPassword" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "postgresql_role" "KeycloakUser" {
  name     = "keycloak"

  login    = true
  password = random_password.StolonKeycloakPassword.result
}

resource "postgresql_database" "KeycloakDB" {
  name     = "keycloak"

  owner = postgresql_role.KeycloakUser.name

  encoding = "UTF8"
}

resource "vault_generic_secret" "KeycloakDB" {
  path = "keycloak/KeycloakDB"

  data_json = <<EOT
{
  "username":   "${postgresql_role.KeycloakUser.name}",
  "password": "${postgresql_role.KeycloakUser.password}"
}
EOT
}

#
# Bitwarden
#
resource "random_password" "StolonBitwardenPassword" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "postgresql_role" "BitwardenUser" {
  name     = "bitwarden"

  login    = true
  password = random_password.StolonBitwardenPassword.result
}

resource "postgresql_database" "BitwardenDB" {
  name     = "bitwarden"

  owner = postgresql_role.BitwardenUser.name
}

resource "vault_generic_secret" "BitwardenDB" {
  path = "keycloak/BitwardenDB"

  data_json = <<EOT
{
  "username":   "${postgresql_role.BitwardenUser.name}",
  "password": "${postgresql_role.BitwardenUser.password}"
}
EOT
}

#
# OpenNMS
# 
resource "random_password" "StolonOpenNMSPassword" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "postgresql_role" "OpenNMSUser" {
  name     = "opennms"

  login    = true
  password = random_password.StolonOpenNMSPassword.result
}

resource "postgresql_database" "OpenNMSDB" {
  name     = "opennms"

  owner = postgresql_role.OpenNMSUser.name
}