terraform {
  required_providers {
    #
    # Minio
    #
    # Docs: https://registry.terraform.io/providers/mrparkers/keycloak/latest/docs
    #
    minio = {
      source  = "aminueza/minio"
      version = "1.2.0"
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

    unifi = {
      source = "paultyng/unifi"
      version = "0.27.0"
    }

    vault = {
      source = "hashicorp/vault"
      version = "2.22.1"
    }
  }
}

data "vault_generic_secret" "unifi" {
  path = "keycloak/UNIFI"
}

provider "unifi" {
  username = "${data.vault_generic_secret.unifi.data["USERNAME"]}" # optionally use UNIFI_USERNAME env var
  password = "${data.vault_generic_secret.unifi.data["PASSWORD"]}" # optionally use UNIFI_PASSWORD env var
  api_url  = "${var.unifiURL}"  # optionally use UNIFI_API env var

  # you may need to allow insecure TLS communications unless you have configured
  # certificates for your controller
  allow_insecure = false

  site = "${var.unifiSite}"
}

data "unifi_port_profile" "all" {
}

resource "unifi_network" "vlan" {
  name    = "kjdev-home1-spine0"
  purpose = "corporate"

  subnet       = "172.16.100.0/24"
  vlan_id      = 20
  dhcp_start   = "10.0.0.6"
  dhcp_stop    = "10.0.0.254"
  dhcp_enabled = true
}

resource "unifi_port_profile" "poe_disabled" {
  name = "POE Disabled"

  native_networkconf_id = unifi_network.vlan.id
  poe_mode              = "off"
}