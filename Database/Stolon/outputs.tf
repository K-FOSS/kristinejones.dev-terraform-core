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