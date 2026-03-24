output "log_archive_bucket_name" {
  description = "Name of the immutable S3 log archive bucket"
  value       = aws_s3_bucket.log_archive.id
}

output "log_archive_bucket_arn" {
  description = "ARN of the immutable S3 log archive bucket"
  value       = aws_s3_bucket.log_archive.arn
}

output "cloudtrail_arn" {
  description = "ARN of the organization-wide CloudTrail trail"
  value       = aws_cloudtrail.org_trail.arn
}

output "cloudtrail_home_region" {
  description = "Home region of the CloudTrail trail"
  value       = aws_cloudtrail.org_trail.home_region
}
