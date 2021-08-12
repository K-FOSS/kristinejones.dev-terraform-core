#
# DNS
#

#
# DNSSec
#
output "DNSSec" {
  value = cloudflare_zone_dnssec.KJDevDNSSec
}