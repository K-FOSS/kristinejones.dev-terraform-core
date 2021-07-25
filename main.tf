terraform {
  required_providers {
    mysql = {
      source = "winebarrel/mysql"
      version = "1.10.4"
    }

    docker = {
      source = "kreuzwerker/docker"
      version = "2.14.0"
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

module "Keycloak" {
  source = "./Keycloak"

  keycloakHostname = "keycloak.kristianjones.dev"
  
  keycloakClientID = "Terraform"
}
