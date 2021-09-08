disable_mlock = true
ui = true
  
listener "tcp" {
  address     = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable = 1
  telemetry {
    unauthenticated_metrics_access = true
  }
}

cluster_name = "kristianjones.dev"

telemetry {
  prometheus_retention_time = "60s"
  disable_hostname = true
}

service_registration "consul" {
  address = "${CONSUL.HOSTNAME}:${CONSUL.PORT}"
  path    = "${CONSUL.PREFIX}"
  service = "${CONSUL.SERVICE_NAME}"

  token = "${CONSUL.ACL_TOKEN}"
}

#
# TODO: Terraform handling Vault unseal ACL & Tokens
#
seal "transit" {
  address = "http://tasks.CoreVault:8200"
  disable_renewal = "false"
  key_name = "autounseal"
  mount_path = "transit/"
  tls_skip_verify = "true"
}

storage "postgresql" {
  connection_url = "postgres://${DATABASE.USERNAME}:${DATABASE.PASSWORD}@${DATABASE.HOSTNAME}:${DATABASE.PORT}/${DATABASE.DATABASE}?sslmode=disable"
  ha_enabled = "true"

  #
  # TODO: Automatically bootstrap Postgres Database
  #
  ha_table = "vault_ha_locks"
}