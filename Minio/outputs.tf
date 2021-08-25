output "NextCloudBucket" {
  value = minio_s3_bucket.nextcloudcore
}

output "TFTPBucket" {
  value = minio_s3_bucket.tftpData
}

#
# OpenNMS
#
output "OpenNMSData" {
  value = minio_s3_bucket.OpenNMSData
}

output "OpenNMSDeployData" {
  value = minio_s3_bucket.OpenNMSDeployData
}

output "OpenNMSCoreData" {
  value = minio_s3_bucket.OpenNMSCoreData
}

output "OpenNMSConfig" {
  value = minio_s3_bucket.OpenNMSConfig
}

output "OpenNMSCassandra" {
  value = minio_s3_bucket.OpenNMSCassandra
}

#
# RocketChat
#

#
# Consul
#

output "Consul1Data" {
  value = minio_s3_bucket.Consul1Data
}

output "Consul2Data" {
  value = minio_s3_bucket.Consul2Data
}

output "Consul3Data" {
  value = minio_s3_bucket.Consul3Data
}