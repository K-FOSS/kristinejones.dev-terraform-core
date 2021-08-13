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

  org_id = 1
}

# resource "grafana_data_source" "prometheus" {
#   type = "prometheus"
#   name = "prometheus"
#   url  = "http://Prometheus:9090"

#   access_mode = "proxy"

#   #is_default = true

#   json_data {
# 		http_method = "GET"
# 		query_timeout = "1"
# 	}
# }

# resource "grafana_data_source" "Loki" {
#   type = "loki"
#   name = "loki"
#   url  = "http://tasks.LokiGateway:8080"

#   access_mode = "proxy"

#   #is_default = true
# }