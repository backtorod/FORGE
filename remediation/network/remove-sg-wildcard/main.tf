################################################################################
# FORGE Remediation: FORGE-NET-001 — Remove Security Group Wildcard Rules
################################################################################

data "archive_file" "handler" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.module}/.build/handler.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = "${var.org_prefix}-remediate-sg-wildcard"
  description      = "FORGE: Remove 0.0.0.0/0 inbound SG rules on blocked ports (FORGE-NET-001)"
  role             = aws_iam_role.this.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.handler.output_path
  source_code_hash = data.archive_file.handler.output_base64sha256
  timeout          = 30
  kms_key_arn      = var.kms_key_arn
  tracing_config { mode = "Active" }
  tags = merge(var.tags, { FORGE_Control = "FORGE-NET-001" })
}

resource "aws_iam_role" "this" {
  name = "${var.org_prefix}-remediate-sg-wildcard"
  path = "/forge/remediation/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "${var.org_prefix}-remediate-sg-wildcard"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ec2:DescribeSecurityGroups", "ec2:RevokeSecurityGroupIngress"], Resource = "*" },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "trigger" {
  name = "${var.org_prefix}-trigger-sg-wildcard"
  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName      = ["FORGE-EC2-003"]
      newEvaluationResult = { complianceType = ["NON_COMPLIANT"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.trigger.name
  target_id = "ForgeRemediateSGWildcard"
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
  alarm_name          = "${var.org_prefix}-remediate-sg-wildcard-errors"
  alarm_description   = "FORGE-EC2-003 remediation Lambda is throwing errors — auto-remediation may be failing"
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

  tags = merge(var.tags, { FORGE_Control = "FORGE-EC2-003" })
}
