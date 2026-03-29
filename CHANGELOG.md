# Changelog

All notable changes to FORGE are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: [Semantic Versioning](https://semver.org/)

---

## [0.2.0] - 2026-03-29

### Added
- CloudWatch error alarms for all 5 remediation Lambda modules — failures page via SNS
- `alert_topic_arn` variable wired into all remediation modules (`s3`, `ec2`, `iam`, `network`, `rds`)
- `alert_email` variable on GuardDuty module with SNS topic subscription for external notification delivery
- `cloudtrail_log_group_name` output on logging module; wired into IAM baseline for metric filter
- CloudTrail log group metric filter + `FORGE/Security` namespace alarm replacing broken `AWS/CloudTrail` alarm
- Compliance test suite: 34 tests covering all deployed FORGE Config rules, recorder status, delivery channel, and service availability

### Fixed
- S3 remediation Lambda not triggering: rule identifier corrected from `S3_BUCKET_PUBLIC_READ_PROHIBITED` (periodic) to `S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED` (change-triggered)
- S3 Lambda event parsing: bucket name now read from `event.detail.resourceId` for Config Rules Compliance Change EventBridge events
- IAM policy on S3 Lambda: `s3:HeadBucket` (not a valid IAM action) removed; replaced with `s3:ListBucket`
- `botocore.exceptions.ClientError` import corrected in S3 handler (`s3.exceptions.ClientError` is not valid on a boto3 client)
- Replaced broken `FORGE-BreakGlassRoleused` CloudWatch alarm (used nonexistent `AWS/CloudTrail` namespace) with a CWL metric filter on the CloudTrail log group publishing to `FORGE/Security` namespace
- Compliance tests: `boto3.client('configservice')` corrected to `boto3.client('config')` (`configservice` is the AWS CLI convention; boto3 uses `config`)
- Compliance tests: `FORGE-CT-*` and `FORGE-GD-001` rule name references aligned to deployed Terraform identifiers (were `FORGE-TRAIL-*` / `FORGE-DETECT-001`)
- Compliance test `test_cloudtrail_enabled`: `CLOUD_TRAIL_ENABLED` is a periodic/account-level rule with no per-resource counts; switched to `describe_compliance_by_config_rule` to assert rule-level compliance type

### Verified
- All 34 compliance tests passing
- S3 remediation end-to-end confirmed: violation → Config → EventBridge → Lambda → blocked (~35s latency)
- 8 CloudWatch alarms active with SNS actions (3 detective, 5 remediation error)

---

## [0.1.1] - 2026-03-25

### Added
- `examples/regulated-enterprise` — full regulated-enterprise example configuration with advanced network topology, multi-region support, and extended compliance controls
- README for regulated-enterprise example documenting configuration options and deployment prerequisites

---

## [0.1.0] - 2026-03-24

### Added
- Initial beta release of all framework modules
- Foundation: organization, SCP library, CloudTrail logging
- Network: VPC baseline (3-tier), Transit Gateway, DNS, **Cloud WAN**, **VPC Peering**
- Identity: IAM baseline, SSO, MFA enforcement
- Security: GuardDuty, Security Hub, Inspector, Config Rules
- Encryption: KMS key hierarchy, TLS enforcement
- Remediation: S3, IAM, EC2, RDS, Network Lambda modules
- Control matrices: NIST SP 800-53, SOC 2, HIPAA, FFIEC CAT
- Examples: baseline-regulated (Cloud WAN + VPC Peering wired), growth-stage, regulated-enterprise
- Docs: whitepaper, deployment guide, runbooks

### Network modules
- `modules/network/cloudwan` — AWS Cloud WAN global network with 3-segment policy (workload / shared-services / inspection), tag-driven VPC attachment assignment, org-wide RAM sharing, and CloudWatch attachment health alarms
- `modules/network/vpc-peering` — Cross-region intra-account VPC peering mesh; bidirectional route injection and optional DNS resolution across peering links; intended for accounts that span multiple regions and must be treated as a single network entity

---

## [0.1.0-beta] - 2026-03-19

### Added
- Initial repository structure
- FORGE Technical White Paper
- Apache 2.0 license
- Pre-commit hooks (Checkov, Bandit, terraform fmt)
