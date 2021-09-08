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

storage "consul" {
  address = "${CONSUL.HOSTNAME}:${CONSUL.PORT}"
  path    = "${CONSUL.PREFIX}"
  service = "${CONSUL.SERVICE_NAME}"

  token = "${CONSUL.ACL_TOKEN}"
}