variable "audit_account_id" { type = string }
variable "target_account_ids" { type = list(string) }
variable "auto_enable_ec2" { type = bool; default = true }
variable "auto_enable_ecr" { type = bool; default = true }
variable "auto_enable_lambda" { type = bool; default = true }
variable "auto_enable_lambda_code" { type = bool; default = true }
variable "tags" { type = map(string); default = {} }
