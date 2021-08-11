output "NextCloudBucket" {
  value = minio_s3_bucket.nextcloudcore
}

output "TFTPBucket" {
  value = minio_s3_bucket.tftpData
}