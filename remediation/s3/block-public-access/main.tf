################################################################################
# FORGE Remediation: FORGE-S3-001 — Block Public Access
# Packages and deploys the Lambda; wires AWS Config → EventBridge → Lambda
################################################################################

data "archive_file" "handler" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.module}/.build/handler.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = "forge-remediate-s3-block-public-access"
  description      = "FORGE: Auto-remediate public S3 buckets (FORGE-S3-001)"
  role             = aws_iam_role.this.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.handler.output_path
  source_code_hash = data.archive_file.handler.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      LOG_LEVEL     = var.log_level
      FORGE_CONTROL = "FORGE-S3-001"
    }
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    FORGE_Control = "FORGE-S3-001"
    NIST_Control  = "AC-3 SC-7"
    SOC2_Control  = "CC6.1"
  })
}

resource "aws_iam_role" "this" {
  name = "forge-remediate-s3-block-public-access"
  path = "/forge/remediation/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "forge-remediate-s3-block-public-access"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3Remediation"
        Effect   = "Allow"
        Action   = [
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:ListBucket"
        ]
        Resource = "*"
      },
      {
        Sid    = "Logging"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "XRay"
        Effect = "Allow"
        Action = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ]
  })
}

# EventBridge rule: fires when Config marks an S3 bucket as NON_COMPLIANT
resource "aws_cloudwatch_event_rule" "trigger" {
  name        = "forge-trigger-s3-block-public-access"
  description = "FORGE: Trigger S3 public access remediation on Config violation"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName = ["FORGE-S3-001"]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.trigger.name
  target_id = "ForgRemediateS3"
  arn       = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trigger.arn
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "forge-remediate-s3-block-public-access-errors"
  alarm_description   = "FORGE-S3-001 remediation Lambda is throwing errors — auto-remediation may be failing"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alert_topic_arn]

  dimensions = { FunctionName = aws_lambda_function.this.function_name }

  tags = merge(var.tags, { FORGE_Control = "FORGE-S3-001" })
}
