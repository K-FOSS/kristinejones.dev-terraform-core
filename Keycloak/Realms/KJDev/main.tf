resource "keycloak_realm" "kjdev" {
  realm             = "KJDev"
  enabled           = true

  login_theme = "keycloak"
  account_theme = "keycloak.v2"
  admin_theme = "keycloak"

  access_code_lifespan = "30m"


  internationalization {
    supported_locales = [
      "en",
      "de",
      "es",
    ]

    default_locale = "en"
  }

  security_defenses {
    headers {
      x_frame_options                     = "DENY"
      content_security_policy             = "frame-src 'self'; frame-ancestors 'self'; object-src 'none';"
      content_security_policy_report_only = ""
      x_content_type_options              = "nosniff"
      x_robots_tag                        = "none"
      x_xss_protection                    = "1; mode=block"
      strict_transport_security           = "max-age=31536000; includeSubDomains"
    }

    brute_force_detection {
      permanent_lockout                = false
      max_login_failures               = 31
      wait_increment_seconds           = 61
      quick_login_check_milli_seconds  = 1000
      minimum_quick_login_wait_seconds = 120
      max_failure_wait_seconds         = 900
      failure_reset_time_seconds       = 43200
    }
  }

  web_authn_policy {
    relying_party_entity_name = "KJDev Int"
    relying_party_id          = var.url
    signature_algorithms      = [
      "ES256",
      "RS256"]
  }

  web_authn_passwordless_policy {
    relying_party_entity_name = "KJDev Int"
    relying_party_id          = var.url
    signature_algorithms      = [
      "ES256",
      "RS256"]
  }
}

module "OpenLDAP" {
  source = "./UserFederation/OpenLDAP"

  realmID = "${keycloak_realm.kjdev.id}"
}

module "MinioClient" {
  source = "./Clients/Minio"
}