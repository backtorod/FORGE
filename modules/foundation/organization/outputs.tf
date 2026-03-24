output "organization_id" {
  description = "The AWS Organization ID"
  value       = aws_organizations_organization.this.id
}

output "organization_arn" {
  description = "The ARN of the AWS Organization — used by Cloud WAN RAM sharing."
  value       = aws_organizations_organization.this.arn
}

output "organization_root_id" {
  description = "The root ID of the AWS Organization"
  value       = aws_organizations_organization.this.roots[0].id
}

output "ou_security_id" {
  description = "OU ID for the Security organizational unit"
  value       = aws_organizations_organizational_unit.security.id
}

output "ou_infrastructure_id" {
  description = "OU ID for the Infrastructure organizational unit"
  value       = aws_organizations_organizational_unit.infrastructure.id
}

output "ou_workloads_prod_id" {
  description = "OU ID for the Production Workloads organizational unit"
  value       = aws_organizations_organizational_unit.workloads_prod.id
}

output "ou_workloads_nonprod_id" {
  description = "OU ID for the Non-Production Workloads organizational unit"
  value       = aws_organizations_organizational_unit.workloads_nonprod.id
}

output "ou_sandbox_id" {
  description = "OU ID for the Sandbox organizational unit"
  value       = aws_organizations_organizational_unit.sandbox.id
}

output "log_archive_account_id" {
  description = "Account ID of the Log Archive account"
  value       = aws_organizations_account.log_archive.id
}

output "audit_account_id" {
  description = "Account ID of the Audit account"
  value       = aws_organizations_account.audit.id
}

output "network_account_id" {
  description = "Account ID of the Network account"
  value       = aws_organizations_account.network.id
}

output "shared_services_account_id" {
  description = "Account ID of the Shared Services account"
  value       = aws_organizations_account.shared_services.id
}
