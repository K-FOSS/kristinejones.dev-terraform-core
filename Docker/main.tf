terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "2.14.0"
    }

    minio = {
      source  = "aminueza/minio"
      version = "1.2.0"
    }

    vault = {
      source = "hashicorp/vault"
      version = "2.22.1"
    }
  }
}

data "vault_generic_secret" "minio" {
  path = "keycloak/MINIO"
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_plugin" "s3core-storage" {
  name                  = "rexray/s3fs"
  alias                 = "s3core-storage"
  enabled               = true
  grant_all_permissions = true
  force_destroy         = true
  enable_timeout        = 300
  force_disable         = true
  env = [
    "S3FS_OPTIONS=allow_other,use_path_request_style,nonempty,url=${var.minioURL}",
    "S3FS_ENDPOINT=${var.minioURL}",
    "S3FS_ACCESSKEY=${data.vault_generic_secret.minio.data["ACCESS_KEY"]}",
    "S3FS_SECRETKEY=${data.vault_generic_secret.minio.data["SECRET_KEY"]}"
  ]
}