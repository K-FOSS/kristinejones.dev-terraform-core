terraform {
  required_providers {
    consul = {
      source = "hashicorp/consul"
      version = "2.12.0"
    }

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

    minio = {
      source = "aminueza/minio"
      version = "1.2.0"
    }

    postgresql = {
      source = "cyrilgdn/postgresql"
      version = "1.13.0"
    }

    tinkerbell = {
      source  = "tinkerbell/tinkerbell"
      version = "0.1.0"
    }

    unifi = {
      source = "paultyng/unifi"
      version = "0.27.0"
    }

    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
  }
}

module "Keycloak" {
  source = "./Keycloak"

  keycloakHostname = "keycloak.kristianjones.dev"
  
  keycloakClientID = "Terraform"
}

module "Minio" {
  source = "./Minio"

  minioHostname = "s3core.kristianjones.dev"
  minioPort = 443
}

module "Docker" {
  source = "./Docker"

  minioURL = "https://s3core.kristianjones.dev:9443"
}

# module "Unifi" {
#   source = "./Network/Unifi"

#   unifiURL = "https://unifi.kristianjones.dev"

#   unifiSite = "default"
# }

module "Database" {
  source = "./Database"
}

module "Tinkerbell" {
  source = "./Tinkerbell"
}

module "Consul" {
  source = "./Hashicorp/Consul"

  consulHostname = "consul.kristianjones.dev"
  consulPort = 443

  consulDatacenter = "dc1"
}

module "CoreVault" {
  source = "./Hashicorp/CoreVault"

  OpenIDClientID = module.Keycloak.VaultOIDClient.client_id

  OpenIDClientSecret = module.Keycloak.VaultOIDClient.client_secret

  OpenIDEndpoint = "https://keycloak.kristianjones.dev"

  VaultURL = "http://tasks.CoreVault:8200"
}

module "Vault" {
  source = "./Hashicorp/Vault"

  OpenIDClientID = module.Keycloak.KJDevRealm.VaultClientModule.Client.client_id

  OpenIDClientSecret = module.Keycloak.KJDevRealm.VaultClientModule.Client.client_secret

  VaultClient = module.Keycloak.KJDevRealm.VaultClientModule

  OpenIDEndpoint = "https://keycloak.kristianjones.dev"
}