terraform {
  required_providers {
    postgresql = {
      source = "cyrilgdn/postgresql"
      version = "1.13.0"
    }
  }
}

provider "postgresql" {
  host            = "tasks.${var.postgresDatabaseService.name}"
  port            = 5432
  username        = "postgres"
  password        = "helloWorld"
}

resource "postgresql_database" "hashicorpBoundary" {
  name     = "boundary1"
}
