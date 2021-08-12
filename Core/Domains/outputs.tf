#
# DNS
#

#
# DNSSec
#
output "DNSSec" {
  value = data.cloudflare_zone_dnssec.KJDevDNSSec
}