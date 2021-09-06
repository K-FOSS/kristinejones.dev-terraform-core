// output "Grafana" {
//   value = consul_service.Grafana
// }

#
# Grafana Loki
#

# output "LokiToken" {
#   value = consul_acl_token.LokiToken
# }

output "LokiSecretToken" {
  value = data.consul_acl_token_secret_id.LokiToken
}

# #
# # Grafana Cortex
# #

# output "CortexACL" {
#   value = "test"
# }

output "CortexSecretToken" {
  value = data.consul_acl_token_secret_id.CortexToken
}