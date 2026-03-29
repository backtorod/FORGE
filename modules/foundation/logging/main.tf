################################################################################
# FORGE — Foundation: Centralized Logging
# Deploys immutable CloudTrail org trail and S3 log archive bucket
# Regulatory: NIST AU-2, AU-3, AU-9 | SOC2 CC7.2, CC7.3 | FFIEC IS.10
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# S3 Log Archive Bucket (Log Archive Account)
# Immutable: SCPs prevent deletion; Object Lock enforces retention
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "log_archive" {
  bucket = "forge-audit-logs-${var.log_archive_account_id}-${data.aws_region.current.region}"

  tags = merge(var.tags, {
    FORGE_Control     = "LOG-001"
    NIST_Control      = "AU-2 AU-3 AU-9"
    SOC2_Control      = "CC7.2 CC7.3"
    FFIEC_Control     = "IS.10"
    Compliance_Status = "enforced"
    Immutable         = "true"
  })
}

resource "aws_s3_bucket_versioning" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  depends_on = [aws_s3_bucket_versioning.log_archive]

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.log_retention_days
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    id     = "forge-log-lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 2555 # 7-year retention — FFIEC requirement
    }
  }
}

resource "aws_s3_bucket_policy" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id
  policy = data.aws_iam_policy_document.log_archive_bucket_policy.json
}

data "aws_iam_policy_document" "log_archive_bucket_policy" {
  statement {
    sid    = "DenyNonTLS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.log_archive.arn, "${aws_s3_bucket.log_archive.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl", "s3:PutObject"]
    resources = [aws_s3_bucket.log_archive.arn, "${aws_s3_bucket.log_archive.arn}/AWSLogs/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceOrgID"
      values   = [var.organization_id]
    }
  }
}

# -----------------------------------------------------------------------------
# Organization-wide CloudTrail
# Deployed in management account; writes to Log Archive account S3
# -----------------------------------------------------------------------------

resource "aws_cloudtrail" "org_trail" {
  name                          = "forge-org-trail"
  s3_bucket_name                = aws_s3_bucket.log_archive.id
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = var.kms_key_arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }

  tags = merge(var.tags, {
    FORGE_Control = "LOG-002"
    NIST_Control  = "AU-2 AU-12"
    Immutable     = "true"
  })
}

# -----------------------------------------------------------------------------
# Root account login detection
# SCPs cannot block root on the management account — CloudWatch alarm is the
# compensating control (NIST AC-6(9), CIS AWS Benchmark 1.7)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/forge/cloudtrail/org"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, { FORGE_Control = "LOG-003" })
}

resource "aws_cloudwatch_log_metric_filter" "root_login" {
  name           = "forge-root-account-usage"
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "FORGE/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_login" {
  alarm_name          = "forge-root-account-usage"
  alarm_description   = "FORGE: Root account activity detected - immediate investigation required (NIST AC-6(9))"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "FORGE/Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = []

  tags = merge(var.tags, {
    FORGE_Control = "LOG-003"
    NIST_Control  = "AC-6-9"
    SOC2_Control  = "CC6.3"
  })
}
