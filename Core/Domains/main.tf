terraform {
  required_providers {
    consul = {
      source = "hashicorp/consul"
      version = "2.12.0"
    }

    #
    # CloudFlare Provider
    #
    # Docs: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs
    # 
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "2.25.0"
    }

    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.CFToken
}

data "cloudflare_zones" "domain" {
  filter {
    name = var.domain
  }
}

data "cloudflare_zone_dnssec" "KJDevDNSSec" {
  zone_id = lookup(data.cloudflare_zones.domain.zones[0], "id")
}