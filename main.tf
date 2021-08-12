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
      version = "2.15.0"
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



# module "Unifi" {
#   source = "./Network/Unifi"

#   unifiURL = "https://unifi.kristianjones.dev"

#   unifiSite = "default"
# }

module "Database" {
  source = "./Database/Stolon"
}

module "Docker" {
  source = "./Docker"

  #
  # Keycloak
  #
  KeycloakModule = module.Keycloak
  StolonKeycloakRole = module.Database.KeycloakRole
  StolonKeycloakDB = module.Database.KeycloakDB

  #
  # Bitwarden
  #
  StolonBitwardenRole = module.Database.BitwardenRole
  StolonBitwardenDB = module.Database.BitwardenDB

  #
  # TFTP
  #
  TFTPBucket = module.Minio.TFTPBucket

  #
  # OpenNMS
  #

  # Volumes
  OpenNMSDataBucket = module.Minio.OpenNMSData
  OpenNMSCoreDataBucket = module.Minio.OpenNMSCoreData
  OpenNMSConfigBucket = module.Minio.OpenNMSConfig
  OpenNMSCassandraBucket = module.Minio.OpenNMSCassandra
  OpenNMSDeployDataBucket = module.Minio.OpenNMSDeployData

  # Database
  StolonOpenNMSRole = module.Database.OpenNMSRole
  StolonOpenNMSDB = module.Database.OpenNMSDB

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

  KeycloakModule = module.Keycloak

  VaultURL = "http://tasks.CoreVault:8200"
}

module "Vault" {
  source = "./Hashicorp/Vault"

  KeycloakModule = module.Keycloak

  StolonRole = module.Database.VaultRole
}