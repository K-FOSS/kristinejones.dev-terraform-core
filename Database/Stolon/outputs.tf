#
# Vault
#

output "VaultRole" {
  value = postgresql_role.vault
}

#
# Keycloak
#
output "KeycloakRole" {
  value = postgresql_role.KeycloakUser
}

output "KeycloakDB" {
  value = postgresql_database.KeycloakDB
}

#
# Bitwarden
#
output "BitwardenRole" {
  value = postgresql_role.BitwardenUser
}

output "BitwardenDB" {
  value = postgresql_database.BitwardenDB
}

#
# OpenNMS
#
output "OpenNMSRole" {
  value = postgresql_role.OpenNMSUser
}

output "OpenNMSDB" {
  value = postgresql_database.OpenNMSDB
}

#
# ISC Network Infra
#

#
# DHCP
#
output "DHCPRole" {
  value = postgresql_role.DHCPUser
}

output "DHCPDB" {
  value = postgresql_database.DHCPDB
}

#
# ISC Stork
#
output "StorkRole" {
  value = postgresql_role.StorkUser
}

output "StorkDB" {
  value = postgresql_database.StorkDB
}

#
# NetBox
#

output "NetboxRole" {
  value = postgresql_role.NetboxUser
}

output "NetboxDB" {
  value = postgresql_database.NetboxDB
}

#
# Insights
#

#
# Grafana
# 

output "GrafanaRole" {
  value = postgresql_role.GrafanaUser
}

output "GrafanaDB" {
  value = postgresql_database.GrafanaDB
}

#
# OpenProject
#

output "OpenProjectRole" {
  value = postgresql_role.OpenProjectUser
}

output "OpenProjectDB" {
  value = postgresql_database.OpenProjectDB
}
