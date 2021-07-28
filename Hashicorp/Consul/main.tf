terraform {
  required_providers {
    consul = {
      source = "hashicorp/consul"
      version = "2.12.0"
    }

    vault = {
      source = "hashicorp/vault"
      version = "2.22.1"
    }
  }
}

resource "vault_policy" "consulConnectCA" {
  name = "consul-connect-ca"

  policy = file("${path.module}/ConsulCA.hcl")
}

resource "vault_token" "consulConnectCAToken" {
  policies = ["${vault_policy.consulConnectCA.name}"]

  renewable = true
  ttl = "168h"
}

provider "consul" {
  address    = "${var.consulHostname}:${var.consulPort}"
  datacenter = "dc1"

  scheme = "https"
}

data "vault_generic_secret" "vault" {
  path = "keycloak/VAULT"
}

resource "consul_certificate_authority" "connect" {
  connect_provider = "vault"

  config = {
    Address = "https://vault.kristianjones.dev:443"
    Token = "${data.vault_generic_secret.vault.data["TOKEN"]}"
    RootPKIPath = "connect_root"
    IntermediatePKIPath = "connect_inter"
    IntermediateCertTTL = "8760h"
  }
}