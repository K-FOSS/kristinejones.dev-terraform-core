terraform {
  required_providers {
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

resource "keycloak_authentication_flow" "fido2-flow" {
  realm_id = "${var.realmID}"
  alias    = "Browser-FIDO2"
}

resource "keycloak_authentication_execution" "webauthn-cookies" {
  realm_id          = "${var.realmID}"
  parent_flow_alias = "${keycloak_authentication_flow.fido2-flow.alias}"
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
}

resource "keycloak_authentication_subflow" "webauth-forms" {
  realm_id          = "${var.realmID}"
  parent_flow_alias = "${keycloak_authentication_flow.fido2-flow.alias}"
  alias             = "Forms"
  requirement       = "ALTERNATIVE"
  depends_on        = [
    keycloak_authentication_execution.webauthn-cookies
  ]
}

resource "keycloak_authentication_execution" "webauth-form-username" {
  realm_id          = "${var.realmID}"
  parent_flow_alias = "${keycloak_authentication_subflow.webauth-forms.alias}"
  authenticator     = "auth-username-form"
  requirement       = "REQUIRED"
}

resource "keycloak_authentication_subflow" "webauth-forms-webauthn" {
  realm_id          = "${var.realmID}"
  parent_flow_alias = keycloak_authentication_subflow.webauth-forms.alias
  alias             = "Passwordless_Or_2FA"
  requirement       = "REQUIRED"
  depends_on        = [
    keycloak_authentication_execution.webauth-form-username
  ]
}

resource "keycloak_authentication_execution" "webauth-forms-fido2" {
  realm_id          = "${var.realmID}"
  parent_flow_alias = "${keycloak_authentication_subflow.webauth-forms-webauthn.alias}"
  authenticator     = "webauthn-authenticator-passwordless"
  requirement       = "ALTERNATIVE"
}

resource "keycloak_authentication_subflow" "webauth-forms-webauthn-fido2-password" {
  realm_id          = "${var.realmID}"
  parent_flow_alias = "${keycloak_authentication_subflow.webauth-forms-webauthn.alias}"
  alias             = "Password"
  requirement       = "ALTERNATIVE"
  depends_on        = [
    keycloak_authentication_execution.webauth-forms-fido2
  ]
}

resource "keycloak_required_action" "required_action" {
  realm_id = "${var.realmID}"
  alias    = "webauthn-register-passwordless"
  enabled  = true
  name     = "Webauthn Register Passwordless"
}