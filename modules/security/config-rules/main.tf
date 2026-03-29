################################################################################
# FORGE — Security: AWS Config Rules (FORGE Control Set)
# Maps FORGE control matrix to AWS Config managed + custom rules
# Regulatory: NIST CM-2, CM-6, CA-7 | SOC2 CC7.1
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Dedicated S3 bucket for Config delivery — separate from CloudTrail log archive
# to avoid Object Lock / KMS permission conflicts during PutDeliveryChannel validation
resource "aws_s3_bucket" "config" {
  bucket        = "forge-config-delivery-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  force_destroy = false
  tags          = merge(var.tags, { FORGE_Control = "CM-006" })
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.s3_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.config.arn, "${aws_s3_bucket.config.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "AWSConfigBucketPermissionsCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.config.arn
      },
      {
        Sid       = "AWSConfigBucketExistenceCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:ListBucket"
        Resource  = aws_s3_bucket.config.arn
      },
      {
        Sid       = "AWSConfigBucketDelivery"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.config]
}

resource "aws_config_configuration_recorder" "this" {
  name     = "forge-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  recording_mode {
    recording_frequency = "CONTINUOUS"
  }
}

resource "aws_iam_role" "config" {
  name = "forge-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Config writes to a KMS-encrypted S3 bucket — the role needs GenerateDataKey
resource "aws_iam_role_policy" "config_kms" {
  name = "forge-config-kms"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
      Resource = var.s3_kms_key_arn
    }]
  })
}

resource "aws_config_delivery_channel" "this" {
  name           = "forge-config-delivery"
  s3_bucket_name = aws_s3_bucket.config.id
  s3_kms_key_arn = var.s3_kms_key_arn

  depends_on = [
    aws_config_configuration_recorder.this,
    aws_s3_bucket_policy.config,
  ]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

# -----------------------------------------------------------------------------
# FORGE Managed Config Rules (mapped to control matrix)
# -----------------------------------------------------------------------------

locals {
  managed_rules = {
    # S3
    "FORGE-S3-001" = { rule = "S3_BUCKET_PUBLIC_READ_PROHIBITED",   params = {} }
    "FORGE-S3-002" = { rule = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED",  params = {} }
    "FORGE-S3-003" = { rule = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED", params = {} }
    "FORGE-S3-004" = { rule = "S3_BUCKET_SSL_REQUESTS_ONLY",        params = {} }
    "FORGE-S3-005" = { rule = "S3_BUCKET_VERSIONING_ENABLED",       params = {} }
    # IAM
    "FORGE-IAM-001" = { rule = "IAM_PASSWORD_POLICY",               params = {
      RequireUppercaseCharacters = "true"
      RequireLowercaseCharacters = "true"
      RequireSymbols             = "true"
      RequireNumbers             = "true"
      MinimumPasswordLength      = "16"
      PasswordReusePrevention    = "24"
      MaxPasswordAge             = "90"
    }}
    "FORGE-IAM-002" = { rule = "IAM_ROOT_ACCESS_KEY_CHECK",         params = {} }
    "FORGE-IAM-003" = { rule = "MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS", params = {} }
    "FORGE-IAM-004" = { rule = "IAM_USER_NO_POLICIES_CHECK",        params = {} }
    "FORGE-IAM-005" = { rule = "IAM_NO_INLINE_POLICY_CHECK",        params = {} }
    "FORGE-IAM-006" = { rule = "ACCESS_KEYS_ROTATED",               params = { maxAccessKeyAge = "90" } }
    # EC2 / EBS
    "FORGE-EC2-001" = { rule = "EC2_EBS_ENCRYPTION_BY_DEFAULT",     params = {} }
    "FORGE-EC2-002" = { rule = "EC2_INSTANCE_NO_PUBLIC_IP",         params = {} }
    "FORGE-EC2-003" = { rule = "RESTRICTED_INCOMING_TRAFFIC",       params = {
      blockedPort1 = "22"
      blockedPort2 = "3389"
    }}
    # RDS
    "FORGE-RDS-001" = { rule = "RDS_STORAGE_ENCRYPTED",             params = {} }
    "FORGE-RDS-002" = { rule = "RDS_INSTANCE_PUBLIC_ACCESS_CHECK",  params = {} }
    "FORGE-RDS-003" = { rule = "RDS_MULTI_AZ_SUPPORT",              params = {} }
    "FORGE-RDS-004" = { rule = "RDS_AUTOMATIC_MINOR_VERSION_UPGRADE_ENABLED", params = {} }
    # CloudTrail
    "FORGE-CT-001"  = { rule = "CLOUD_TRAIL_ENABLED",               params = {} }
    "FORGE-CT-002"  = { rule = "MULTI_REGION_CLOUD_TRAIL_ENABLED",   params = {} }
    "FORGE-CT-003"  = { rule = "CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED", params = {} }
    "FORGE-CT-004"  = { rule = "CLOUD_TRAIL_CLOUD_WATCH_LOGS_ENABLED", params = {} }
    # KMS
    "FORGE-KMS-001" = { rule = "KMS_CMK_NOT_SCHEDULED_FOR_DELETION", params = {} }
    # GuardDuty
    "FORGE-GD-001"  = { rule = "GUARDDUTY_ENABLED_CENTRALIZED",     params = {} }
  }
}

resource "aws_config_config_rule" "managed" {
  for_each = local.managed_rules

  name = each.key

  source {
    owner             = "AWS"
    source_identifier = each.value.rule
  }

  input_parameters = length(each.value.params) > 0 ? jsonencode(each.value.params) : null

  tags = merge(var.tags, {
    FORGE_Control = each.key
  })

  depends_on = [aws_config_configuration_recorder_status.this]
}
