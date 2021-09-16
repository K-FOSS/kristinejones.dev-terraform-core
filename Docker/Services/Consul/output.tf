// output "Grafana" {
//   value = consul_service.Grafana
// }

#
# Hashicorp
# 

#
# Hashicorp Vault
#

#
# CoreVault
#

output "CoreVaultSecretToken" {
  value = data.consul_acl_token_secret_id.CoreVaultToken
}

#
# Vault
#  

output "VaultSecretToken" {
  value = data.consul_acl_token_secret_id.VaultToken
}

#
# Hashicorp Nomad
#

#
# CoreNomad
# 

output "CoreNomadSecretToken" {
  value = data.consul_acl_token_secret_id.CoreNomadToken
}


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

#
# Grafana Token
#
output "GrafanaSecretToken" {
  value = data.consul_acl_token_secret_id.GrafanaToken
}

#
# Patroni
#

output "PatroniSecretToken" {
  value = data.consul_acl_token_secret_id.PatroniToken
}

#
# Nomad Jobs
#

#
# TODO: Figure out how to create Nomad services here and export details to Nomad Module (Intentions, HTTP/TCP/UDP, etc)
#

# output "Nomad" {
#   value = {
#     dhcp = {
#       ecs = module.dhcp.ecs
#       ecr = module.dhcp.ecr
#     }
#   }
# }