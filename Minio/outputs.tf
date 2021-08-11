output "NextCloudBucket" {
  value = minio_s3_bucket.nextcloudcore
}

output "TFTPBucket" {
  value = minio_s3_bucket.tftpData
}

output "OpenNMSData" {
  value = minio_s3_bucket.OpenNMSData
}

output "OpenNMSCoreData" {
  value = minio_s3_bucket.OpenNMSCoreData
}

output "OpenNMSConfig" {
  value = minio_s3_bucket.OpenNMSConfig
}
