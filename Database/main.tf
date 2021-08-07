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
