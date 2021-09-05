// output "Grafana" {
//   value = consul_service.Grafana
// }

#
# Grafana Loki
#

output "LokiToken" {
  value = consul_acl_token.LokiToken
}

#
# Grafana Cortex
#

output "CortexACL" {
  value = consul_acl_policy.CortexACL
}

output "CortexToken" {
  value = consul_acl_token.CortexToken
}