# FORGE
### Framework for Operational Regulatory Governance and Enforcement

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-purple.svg)](https://www.terraform.io/)
[![Version: v0.2.0](https://img.shields.io/badge/Version-v0.2.0-green.svg)](CHANGELOG.md)

FORGE is a **public reference architecture and open-source methodology** for
audit-ready, governance-by-design cloud infrastructure in U.S. regulated financial
environments.

The framework addresses a structural gap: federal compliance standards — FFIEC,
NIST SP 800-53, SOC 2, HIPAA — define *what* regulated financial institutions must
achieve. FORGE defines and demonstrates *how*, through programmatically enforced,
immutable infrastructure controls that are publicly documented, reproducible, and
free to adopt.

Published under the Apache License 2.0. No commercial relationship, fee, or
consulting engagement required.

See [FORGE-Whitepaper.md](docs/FORGE-Whitepaper.md) for the full reference
architecture and methodology publication.

---

## Framework Pillars

| Pillar | Description |
|---|---|
| **Immutable Landing Zones** | Multi-account AWS environments where security controls are encoded at the infrastructure layer, making violations architecturally impossible |
| **Compliance Acceleration** | Continuous pipeline that translates FFIEC, NIST, SOC 2, and HIPAA requirements into programmatically enforced, version-controlled infrastructure controls |
| **Original Cross-Framework Control Matrices** | Purpose-built control mappings from regulatory text to executable, auditable code blocks with complete evidentiary traceability |
| **Automated Rollback and Drift Remediation** | Event-driven Lambda modules that detect and automatically remediate configuration drift in near real-time |

---

## Architecture Overview

```
AWS Organization (Management Account)
│
├── Security OU
│   ├── Log Archive Account      ← Immutable, tamper-proof audit logs
│   └── Audit Account            ← Centralized GuardDuty + Security Hub
│
├── Infrastructure OU
│   ├── Network Account          ← Cloud WAN backbone, Transit Gateway, shared VPCs
│   └── Shared Services Account  ← CI/CD, artifact registries
│
├── Workload OU (Production)
│   └── Workload Accounts        ← Isolated blast radius per workload
│
├── Workload OU (Non-Production)
│   └── Staging / Dev Accounts
│
└── Sandbox OU
    └── Unrestricted experimentation, no production data
```

Security controls are enforced at the AWS Organizations layer via Service Control Policies (SCPs) — no account-level override is possible.

---

## Repository Structure

```
forge/
├── modules/                     # Reusable Terraform modules
│   ├── foundation/              # AWS Org, OUs, SCP library, CloudTrail
│   ├── network/                 # VPC baseline, Transit Gateway, Cloud WAN
│   ├── identity/                # IAM policies, SSO, MFA enforcement
│   ├── security/                # GuardDuty, Security Hub, Inspector, Config Rules
│   └── encryption/              # KMS key hierarchy, TLS enforcement
├── remediation/                 # Event-driven Lambda remediation modules
│   └── s3/ iam/ ec2/ rds/ network/
├── control-matrices/            # Regulatory control mappings (YAML)
│   └── nist-800-53/ soc2/ hipaa/ ffiec-cat/ cisa-cpg-2-0/
├── examples/
│   ├── baseline-regulated/      # Community banks, credit unions, Fintech entities
│   ├── growth-stage/            # Regional banks, mid-tier financial services
│   └── regulated-enterprise/    # Large financial institutions and SIFIs
├── docs/
│   ├── FORGE-Whitepaper.md
│   ├── deployment-guide.md
│   └── control-matrix-reference.md
└── tests/
    └── unit/ compliance/ remediation/
```

---

## Quick Start

### Prerequisites

- AWS Organization with management account
- Terraform >= 1.5.0
- AWS CLI v2 (configured with org management credentials)
- Python 3.11+ (for remediation Lambda modules)

### Phase 1: Foundation (Week 1–2)

```bash
cd examples/baseline-regulated
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -target=module.foundation -var-file="terraform.tfvars"
```

See [docs/deployment-guide.md](docs/deployment-guide.md) for the complete four-phase rollout procedure.

---

## Regulatory Coverage

| Standard | Coverage | Automation Level |
|---|---|---|
| SOC 2 Type II | All 9 TSC categories (CC1–CC9) | Fully automated evidence collection |
| NIST SP 800-53 Rev 5 | 11 control families | Preventive + detective controls |
| HIPAA Security Rule | All 3 safeguard categories | Technical controls automated |
| FFIEC CAT | Baseline → Intermediate maturity pathway | Automated + documented |
| CISA CPG 2.0 | Goals 1.B, 2.D, 2.F, 3.A, 3.B | Preventive + detective controls |

---

## Reference Deployments

| Profile | Example | Target Institution | Key Additions |
|---|---|---|---|
| **Baseline Regulated** | [`examples/baseline-regulated/`](examples/baseline-regulated/) | Community banks, credit unions, Fintech entities | Full FORGE foundation: organization, SCPs, KMS, logging, three-tier VPC, Cloud WAN, IAM, MFA, SSO, GuardDuty, Security Hub, Inspector, Config Rules, TLS enforcement, 5 remediation Lambdas |
| **Growth Stage** | [`examples/growth-stage/`](examples/growth-stage/) | Regional banks, mid-tier financial services | Multi-region active-active VPCs (primary + secondary via Cloud WAN), Config Aggregator, Amazon Macie (PHI/PCI discovery), WAFv2 OWASP managed rules, IAM Identity Center SCIM provisioning, SOC 2 + HIPAA dual-standard |
| **Regulated Enterprise** | [`examples/regulated-enterprise/`](examples/regulated-enterprise/) | Large financial institutions, SIFIs, FFIEC/HIPAA-mandated entities | AWS Network Firewall (east-west + north-south inspection), AWS Audit Manager (custom FORGE framework), centralized Backup with Vault Lock (WORM), cross-account EventBridge SIEM bus, NIST 800-53 Rev 5 Config conformance pack, FedRAMP Moderate baseline alignment |

---

## Security

To report a vulnerability in FORGE itself, see [SECURITY.md](SECURITY.md).

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines, including the control matrix peer review process.

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).
