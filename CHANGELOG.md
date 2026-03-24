# Changelog

All notable changes to FORGE are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: [Semantic Versioning](https://semver.org/)

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
