terraform {
  required_providers {
    grafana = {
      source = "grafana/grafana"
      version = "1.13.3"
    }
  }
}

provider "grafana" {
  url  = "http://${var.GrafanaHostname}:8080"
  auth = "${var.GrafanaUser}:${var.GrafanaPassword}"
}

resource "grafana_data_source" "prometheus" {
  type = "prometheus"
  name = "VPS1-RawPrometheus"
  url  = "http://Prometheus:9090"

  access_mode = "proxy"

  is_default = true
}