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

resource "keycloak_openid_client" "minio-oid" {
  realm_id            = keycloak_realm.kjdev.id

  client_id           = "Minio"
  client_secret       = "MinioSecret"

  name                = "Minio"
  enabled             = true

  standard_flow_enabled = true

  access_type         = "CONFIDENTIAL"
  valid_redirect_uris = [
    "https://s3core.kristianjones.dev/oauth_callback"
  ]

  login_theme = "keycloak"
}

resource "keycloak_openid_user_attribute_protocol_mapper" "map_user_attributes_client" {
  name           = "minio"
  realm_id       = keycloak_realm.kjdev.id
  client_id      = keycloak_openid_client.minio-oid.id
  user_attribute = "policy"
  claim_name     = "policy"

  claim_value_type = "String"
}