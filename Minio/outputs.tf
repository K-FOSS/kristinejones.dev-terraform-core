output "NextCloudBucket" {
  value = minio_s3_bucket.nextcloudcore
}

output "PostgresDatabaseBucket" {
  value = minio_s3_bucket.postgresDatabase
}