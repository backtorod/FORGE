output "detector_id" { value = aws_guardduty_detector.audit.id }
output "alerts_topic_arn" { value = aws_sns_topic.guardduty_alerts.arn }
