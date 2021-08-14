terraform {
  required_providers {
    consul = {
      source = "hashicorp/consul"
      version = "2.12.0"
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

    mysql = {
      source = "winebarrel/mysql"
      version = "1.10.4"
    }

    docker = {
      source = "kreuzwerker/docker"
      version = "2.15.0"
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

    vault = {
      source = "hashicorp/vault"
      version = "2.22.1"
    }

    grafana = {
      source = "grafana/grafana"
      version = "1.13.3"
    }
  }
}

#
# Domains
#

#
# CloudFlare
# 

# data "vault_generic_secret" "CF" {
#   path = "${module.Vault.TFMount.path}/CF"
# }


# module "KJDevDomain" {
#   source = "./Core/Domains"

#   domain = "kristianjones.dev"

#   CFToken = data.vault_generic_secret.CF.data["TOKEN"]
# }

#
# AAA
# 

#
# Keycloak
# 
module "Keycloak" {
  source = "./Keycloak"

  keycloakHostname = "keycloak.kristianjones.dev"
  
  keycloakClientID = "Terraform"
}

#
# Storage
#

#
# S3Core/Minio
#
module "Minio" {
  source = "./Minio"

  minioHostname = "s3core.kristianjones.dev"
  minioPort = 443
}

#
# Stolon/Database
#
module "Database" {
  source = "./Database/Stolon"
}

# module "Unifi" {
#   source = "./Network/Unifi"

#   unifiURL = "https://unifi.kristianjones.dev"

#   unifiSite = "default"
# }

#
# Services/Containers/Infra
#

#
# Docker
#
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


  #
  # ISC Network Infra
  #

  #
  # ISC Kea
  #
  StolonDHCPRole = module.Database.DHCPRole
  StolonDHCPDB = module.Database.DHCPDB

  #
  # ISC Stork
  #
  StolonStorkRole = module.Database.StorkRole
  StolonStorkDB = module.Database.StorkDB

  #
  # NetBox
  #
  StolonNetboxRole = module.Database.NetboxRole
  StolonNetboxDB = module.Database.NetboxDB

  #
  # Insights
  # 
  StolonGrafanaRole = module.Database.GrafanaRole
  StolonGrafanaDB = module.Database.GrafanaDB
}

#
# Insights
#
# module "Grafana" {
#   source = "./Insights/Grafana"

#   GrafanaUser = "admin"
#   GrafanaPassword = "admin"

#   GrafanaHostname = "tasks.Grafana"
# }

#
# Tinkerbell/Netboot
#
module "Tinkerbell" {
  source = "./Tinkerbell"
}

#
# Consul/KV/Service Discovery
#
module "Consul" {
  source = "./Hashicorp/Consul"

  consulHostname = "consul.kristianjones.dev"
  consulPort = 443

  consulDatacenter = "dc1"
}

#
# Bootstrap Transit Vault
#
module "CoreVault" {
  source = "./Hashicorp/CoreVault"

  KeycloakModule = module.Keycloak

  VaultURL = "http://tasks.CoreVault:8200"
}

#
# Main Secret Vault
# 
module "Vault" {
  source = "./Hashicorp/Vault"

  KeycloakModule = module.Keycloak

  StolonRole = module.Database.VaultRole

  #
  # DNSSec
  #
  #KJDevDNSSec = module.KJDevDomain.DNSSec
}