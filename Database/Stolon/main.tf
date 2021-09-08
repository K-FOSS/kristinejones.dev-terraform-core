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

#
# ISC Network Infra
#

#
# DHCP
# 

resource "random_password" "StolonDHCPPassword" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "postgresql_role" "DHCPUser" {
  name     = "dhcp"

  login    = true
  password = random_password.StolonDHCPPassword.result
}

resource "postgresql_database" "DHCPDB" {
  name     = "dhcp"

  owner = postgresql_role.DHCPUser.name
}

#
# ISC Stork
# 

resource "random_password" "StolonStorkPassword" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "postgresql_role" "StorkUser" {
  name     = "stork"

  login    = true
  password = random_password.StolonStorkPassword.result
}

resource "postgresql_database" "StorkDB" {
  name     = "stork"

  owner = postgresql_role.StorkUser.name
}

#
# NetBox
# 

resource "random_password" "StolonNetboxPassword" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "postgresql_role" "NetboxUser" {
  name     = "netbox"

  login    = true
  password = random_password.StolonNetboxPassword.result
}

resource "postgresql_database" "NetboxDB" {
  name     = "netbox"

  owner = postgresql_role.NetboxUser.name
}

#
# Insights
#

#
# Grafana
# 

resource "random_password" "StolonGrafanaPassword" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "postgresql_role" "GrafanaUser" {
  name     = "grafana"

  login    = true
  password = random_password.StolonGrafanaPassword.result
}

resource "postgresql_database" "GrafanaDB" {
  name     = "grafana"

  owner = postgresql_role.GrafanaUser.name
}

#
# Nextcloud
# 

resource "random_password" "StolonNextCloudPassword" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "postgresql_role" "NextCloudUser" {
  name     = "nextcloud"

  login    = true
  password = random_password.StolonNextCloudPassword.result
}

resource "postgresql_database" "NextCloudDB" {
  name     = "nextcloud"

  owner = postgresql_role.NextCloudUser.name
}

resource "vault_generic_secret" "NextCloudDB" {
  path = "keycloak/NextCloudDB"

  data_json = <<EOT
{
  "username":   "${postgresql_role.NextCloudUser.name}",
  "password": "${postgresql_role.NextCloudUser.password}"
}
EOT
}

#
# OpenProject
#

resource "random_password" "StolonOpenProjectPassword" {
  length           = 20
  special          = false
}

resource "postgresql_role" "OpenProjectUser" {
  name     = "openproject"

  login    = true
  password = random_password.StolonOpenProjectPassword.result
}

resource "postgresql_database" "OpenProjectDB" {
  name     = "openproject"

  owner = postgresql_role.OpenProjectUser.name
}

#
# Wallabag
#

resource "random_password" "StolonWallabagPassword" {
  length           = 20
  special          = false
}

resource "postgresql_role" "WallabagUser" {
  name     = "wallabag"

  login    = true
  password = random_password.StolonWallabagPassword.result
}

resource "postgresql_database" "WallabagDB" {
  name     = "wallabag"

  owner = postgresql_role.WallabagUser.name
}

#
# Hashicorp
#

#
# Hashicorp Vault
#

resource "random_password" "StolonHashicorpVaultPassword" {
  length  = 20
  special = false

  keepers = {
    # Generate a new id each time we switch to a new AMI id
    meow = "yes"
  }
}

resource "postgresql_role" "HashicorpVaultUser" {
  name     = "hashicorpvault"

  login    = true
  password = random_password.StolonHashicorpVaultPassword.result
}

resource "postgresql_database" "HashicorpVaultDB" {
  name     = "hashicorpvault"

  owner = postgresql_role.HashicorpVaultUser.name
}

resource "vault_generic_secret" "HashicorpVaultDB" {
  path = "keycloak/HashicorpVaultDB"

  data_json = <<EOT
{
  "username":   "${postgresql_role.HashicorpVaultUser.name}",
  "password": "${postgresql_role.HashicorpVaultUser.password}"
}
EOT
}