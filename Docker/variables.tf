# variable "NextCloudBucket" {
#   description = "NextCloudBucket"
# }

# variable "PostgresDatabaseBucket" {
#   description = "Postgres SQL Root Database Minio Bucket"
# }

#
# Keycloak
#

variable "KeycloakModule" {
  
}

#
# Keycloak Database
#

variable "StolonKeycloakRole" {

}

variable "StolonKeycloakDB" {
  
}

#
# Bitwarden
#

variable "StolonBitwardenRole" {

}

variable "StolonBitwardenDB" {
  
}

#
# TFTPd
#
variable "TFTPBucket" {
  
}

#
# OpenNMS
#

#
# Minio/S3 Buckets
# 
variable "OpenNMSDataBucket" {

}

variable "OpenNMSDeployDataBucket" {

}

variable "OpenNMSCoreDataBucket" {

}

variable "OpenNMSConfigBucket" {

}

variable "OpenNMSCassandraBucket" {

}

#
# Stolon/Postgres Database
#

variable "StolonOpenNMSRole" {

}

variable "StolonOpenNMSDB" {
  
}

#
# ISC Network Infra
#

#
# ISC Kea DHCP Server
#

variable "StolonDHCPRole" {

}

variable "StolonDHCPDB" {
  
}

#
# ISC Stork
# 

variable "StolonStorkRole" {

}

variable "StolonStorkDB" {
  
}

#
# NetBox
#
variable "StolonNetboxRole" {

}

variable "StolonNetboxDB" {
  
}

#
# Insights
#

#
# Grafana
#
variable "StolonGrafanaRole" {

}

variable "StolonGrafanaDB" {
  
}