terraform {
  required_providers {
    #
    # Keycloak
    #
    # Docs: https://registry.terraform.io/providers/mrparkers/keycloak/latest/docs
    #
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "3.2.1"
    }

    #
    # Cloudflare
    #
    # Docs: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs
    #
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "2.24.0"
    }

    vault = {
      source = "hashicorp/vault"
      version = "2.22.1"
    }
  }
}

data "vault_generic_secret" "keycloakClient" {
  path = "keycloak/Terraform"
}

provider "keycloak" {
  client_id          = "${var.keycloakClientID}"
  client_secret      = "89fd9ded-08c2-4613-8824-4495bbbdafb3"
  url                = "${var.keycloakProtocol}://${var.keycloakHostname}:${var.keycloakPort}"
}

module "kjdev-realm" {
  source = "./Realms/KJDev"
  
  #
  # TODO: Find more seamless way of detecting this
  #
  firstRun = true
}