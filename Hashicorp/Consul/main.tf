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

# resource "consul_certificate_authority" "connect" {
#   connect_provider = "vault"

#   config = {
#     Address = "https://vault.kristianjones.dev:443"
#     Token = "${vault_token.consulConnectCAToken.client_token}"
#     RootPKIPath = "connect_root"
#     IntermediatePKIPath = "connect_inter"
#     IntermediateCertTTL = "8760h"
#   }
# }