################################################################################
# FORGE Remediation: FORGE-EC2-001 — EBS Encryption by Default
################################################################################

data "archive_file" "handler" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.module}/.build/handler.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = "forge-remediate-ec2-ebs-encryption"
  description      = "FORGE: Enable EBS encryption by default (FORGE-EC2-001)"
  role             = aws_iam_role.this.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.handler.output_path
  source_code_hash = data.archive_file.handler.output_base64sha256
  timeout          = 30
  kms_key_arn      = var.kms_key_arn
  tracing_config { mode = "Active" }
  tags = merge(var.tags, { FORGE_Control = "FORGE-EC2-001" })
}

resource "aws_iam_role" "this" {
  name = "forge-remediate-ec2-ebs-encryption"
  path = "/forge/remediation/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "forge-remediate-ec2-ebs-encryption"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ec2:EnableEbsEncryptionByDefault", "ec2:GetEbsEncryptionByDefault"], Resource = "*" },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "trigger" {
  name = "forge-trigger-ec2-ebs-encryption"
  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName      = ["FORGE-EC2-001"]
      newEvaluationResult = { complianceType = ["NON_COMPLIANT"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.trigger.name
  target_id = "ForgeRemediateEBS"
  arn  = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trigger.arn
}
