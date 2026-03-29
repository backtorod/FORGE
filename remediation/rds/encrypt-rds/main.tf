################################################################################
# FORGE Remediation: FORGE-RDS-001 — RDS Encryption Notification
# NOTE: Live RDS encryption requires snapshot-restore (see runbook).
# This module notifies the security team and logs the violation.
################################################################################

data "archive_file" "handler" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.module}/.build/handler.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = "forge-remediate-rds-encryption"
  description      = "FORGE: Alert on unencrypted RDS — requires manual snapshot-restore runbook"
  role             = aws_iam_role.this.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.handler.output_path
  source_code_hash = data.archive_file.handler.output_base64sha256
  timeout          = 30
  kms_key_arn      = var.kms_key_arn

  environment {
    variables = {
      ALERT_TOPIC_ARN = var.alert_topic_arn
    }
  }

  tracing_config { mode = "Active" }
  tags = merge(var.tags, { FORGE_Control = "FORGE-RDS-001" })
}

resource "aws_iam_role" "this" {
  name = "forge-remediate-rds-encryption"
  path = "/forge/remediation/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "forge-remediate-rds-encryption"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["rds:DescribeDBInstances"], Resource = "*" },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = var.alert_topic_arn },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "trigger" {
  name = "forge-trigger-rds-encryption"
  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName      = ["FORGE-RDS-001"]
      newEvaluationResult = { complianceType = ["NON_COMPLIANT"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.trigger.name
  target_id = "ForgeRemediateRDS"
  arn  = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trigger.arn
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "forge-remediate-rds-encryption-errors"
  alarm_description   = "FORGE-RDS-001 remediation Lambda is throwing errors — auto-remediation may be failing"
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

  tags = merge(var.tags, { FORGE_Control = "FORGE-RDS-001" })
}
