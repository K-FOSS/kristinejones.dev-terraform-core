// output "Grafana" {
//   value = consul_service.Grafana
// }

output "LokiToken" {
  value = consul_acl_token.LokiToken
}