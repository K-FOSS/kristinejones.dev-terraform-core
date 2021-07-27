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

    minio = {
      source = "aminueza/minio"
      version = "1.2.0"
    }

    postgresql = {
      source = "cyrilgdn/postgresql"
      version = "1.13.0"
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

  minioURL = "http://s3core.kristianjones.dev:9000"

  NextCloudBucket = module.Minio.NextCloudBucket
  PostgresDatabaseBucket = module.Minio.PostgresDatabaseBucket
}

# module "Database" {
#   source = "./Database"

#   postgresDatabaseService = module.Docker.PostgresDatabaseService
# }