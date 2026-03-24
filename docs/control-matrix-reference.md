# FORGE Control Matrix Reference

Complete cross-reference of all FORGE control IDs, their enforcement posture,
implementing module, and regulatory mappings across all four supported frameworks.

> Full YAML source files are in [`control-matrices/`](../control-matrices/).

---

## Legend

| Column | Description |
|--------|-------------|
| **Control ID** | FORGE-{SERVICE}-{NUM} unique identifier |
| **Posture** | `preventive` (SCP/Terraform), `detective` (Config/GuardDuty) |
| **Auto-Remediation** | Whether a Lambda remediation module exists |
| **NIST 800-53** | Applicable control families (Rev 5) |
| **SOC 2** | Applicable Trust Services Criteria |
| **HIPAA** | Applicable CFR 164 section(s) |
| **FFIEC** | Applicable CAT domain & maturity |

---

## Organization Controls

| Control ID | Title | Posture | Auto-Remediation | NIST 800-53 | SOC 2 | HIPAA | FFIEC |
|------------|-------|---------|-----------------|-------------|-------|-------|-------|
| FORGE-ORG-001 | AWS Organizations — All Features | preventive | — | CM-2, CM-6, SA-9 | CC1.1, CC5.1 | — | D1.G.IT.B.1 |
| FORGE-ORG-002 | SCP Guardrail Baseline | preventive | — | AC-2, AC-3, CM-6 | CC5.1, CC6.1 | — | D3.PC.Am.B.1 |

## Logging Controls

| Control ID | Title | Posture | Auto-Remediation | NIST 800-53 | SOC 2 | HIPAA | FFIEC |
|------------|-------|---------|-----------------|-------------|-------|-------|-------|
| FORGE-LOG-001 | Immutable CloudTrail | preventive | — | AU-2, AU-3, AU-9 | CC4.1, CC7.2 | 164.312(b) | D3.DC.Ev.B.1 |
| FORGE-LOG-002 | S3 Object Lock COMPLIANCE | preventive | — | AU-9, AU-11 | CC7.3, C1.1 | 164.312(b) | D3.DC.Ev.B.1 |

## IAM / Identity Controls

| Control ID | Title | Posture | Auto-Remediation | NIST 800-53 | SOC 2 | HIPAA | FFIEC |
|------------|-------|---------|-----------------|-------------|-------|-------|-------|
| FORGE-IAM-001 | Permission Boundary | preventive | — | AC-2, AC-6 | CC6.1, CC6.3 | 164.308(a)(4) | D3.PC.Am.B.4 |
| FORGE-IAM-002 | Password Policy | preventive | — | IA-5, IA-5(1) | CC6.1 | 164.308(a)(5)(ii)(D) | D3.PC.Am.B.6 |
| FORGE-IAM-003 | MFA Enforcement SCP | preventive | ✓ iam/mfa-gap-remediation | IA-2, IA-2(1) | CC6.1, CC6.3 | 164.312(d) | D3.PC.Am.B.12 |
| FORGE-IAM-004 | IAM Access Analyzer | detective | — | AC-3, RA-5 | CC6.1, CC3.2 | 164.308(a)(4) | D3.PC.Am.B.1 |
| FORGE-IAM-005 | Break-Glass Role | detective | — | AC-2(5), IR-4 | CC6.3, CC7.3 | 164.312(a)(2)(ii) | D5.IR.Pl.B.4 |

## Network Controls

| Control ID | Title | Posture | Auto-Remediation | NIST 800-53 | SOC 2 | HIPAA | FFIEC |
|------------|-------|---------|-----------------|-------------|-------|-------|-------|
| FORGE-NET-001 | Three-Tier VPC Segmentation | preventive | — | SC-7, AC-4 | CC6.6, CC9.2 | 164.312(a)(1) | D3.PC.Im.B.7 |
| FORGE-NET-002 | VPC Flow Logs | detective | — | AU-2, AU-12 | CC7.2, CC4.1 | 164.312(b) | D3.DC.Ev.B.1 |
| FORGE-NET-003 | Default SG/NACL Empty | preventive | — | SC-7, CM-7 | CC6.6, CC5.1 | 164.312(a)(1) | D3.PC.Im.B.7 |
| FORGE-NET-004 | Cloud WAN — Global Network Backbone | preventive | — | SC-7, SC-7(4), CM-2 | CC9.2, CC6.6 | 164.312(e)(1) | D3.PC.Im.B.7 |
| FORGE-NET-005 | VPC Peering — Cross-Region Intra-Account | preventive | — | SC-7, AC-4 | CC6.6 | 164.312(a)(1) | D3.PC.Im.B.7 |

## S3 Controls

| Control ID | Title | Posture | Auto-Remediation | NIST 800-53 | SOC 2 | HIPAA | FFIEC |
|------------|-------|---------|-----------------|-------------|-------|-------|-------|
| FORGE-S3-001 | S3 Public Access Block | detective | ✓ s3/block-public-access | AC-3, SC-7 | CC6.1, C1.1 | 164.312(a)(1) | D3.PC.Im.B.12 |
| FORGE-S3-002 | S3 TLS-Only (SCP) | preventive | — | SC-8, SC-28 | CC6.7, C1.1 | 164.312(e)(1) | D3.PC.Im.B.14 |
| FORGE-S3-003 | S3 SSE-KMS Mandatory | preventive | — | SC-28 | C1.1, C1.2 | 164.312(a)(2)(iv) | D3.PC.Im.B.13 |

## EC2 / EBS Controls

| Control ID | Title | Posture | Auto-Remediation | NIST 800-53 | SOC 2 | HIPAA | FFIEC |
|------------|-------|---------|-----------------|-------------|-------|-------|-------|
| FORGE-EC2-001 | EBS Encryption by Default | detective | ✓ ec2/encrypt-ebs | SC-28 | C1.1, C1.2 | 164.312(a)(2)(iv) | D3.PC.Im.B.13 |
| FORGE-EC2-002 | EBS Encryption SCP | preventive | — | SC-28 | C1.1 | 164.312(a)(2)(iv) | D3.PC.Im.B.13 |
| FORGE-EC2-003 | No SG Wildcard Ingress | detective | ✓ network/remove-sg-wildcard | SC-7, CM-7 | CC6.6, CC6.7 | 164.312(a)(1) | D3.PC.Im.B.7 |

## RDS Controls

| Control ID | Title | Posture | Auto-Remediation | NIST 800-53 | SOC 2 | HIPAA | FFIEC |
|------------|-------|---------|-----------------|-------------|-------|-------|-------|
| FORGE-RDS-001 | RDS Encryption at Rest | detective | ✓ rds/encrypt-rds (alert) | SC-28 | C1.1, C1.2 | 164.312(a)(2)(iv) | D3.PC.Im.B.13 |
| FORGE-RDS-002 | RDS Multi-AZ SCP | preventive | — | CP-9, CP-10 | A1.2, A1.3 | 164.308(a)(7) | D5.DR.Pl.B.3 |
| FORGE-RDS-003 | RDS No Public Snapshots | preventive | — | AC-3, SC-7 | CC6.1 | 164.312(a)(1) | D3.PC.Im.B.12 |

## Encryption Controls

| Control ID | Title | Posture | Auto-Remediation | NIST 800-53 | SOC 2 | HIPAA | FFIEC |
|------------|-------|---------|-----------------|-------------|-------|-------|-------|
| FORGE-KMS-001 | KMS Annual Key Rotation | preventive | — | SC-12, SC-28 | C1.1, CC6.7 | 164.312(a)(2)(iv) | D3.PC.Im.B.13 |

## Detection Controls

| Control ID | Title | Posture | Auto-Remediation | NIST 800-53 | SOC 2 | HIPAA | FFIEC |
|------------|-------|---------|-----------------|-------------|-------|-------|-------|
| FORGE-DETECT-001 | GuardDuty Org-Wide | detective | — | SI-3, SI-4, IR-4 | CC7.1, CC7.4 | 164.308(a)(6)(ii) | D2.TI.Ti.B.1 |
| FORGE-DETECT-002 | Security Hub Aggregator | detective | — | CA-2, CA-7, RA-5 | CC4.1, CC7.5 | 164.308(a)(8) | D1.RM.Ra.E.1 |
| FORGE-DETECT-003 | Inspector v2 | detective | — | RA-5, SA-11 | CC3.2, CC7.1 | 164.308(a)(1)(ii)(A) | D1.RM.Ra.B.1 |
| FORGE-DETECT-004 | Config Continuous Recording | detective | — | CM-2, CM-6, CM-8 | CC4.1, CC7.2 | — | D3.DC.Ev.B.1 |

---

## Summary Counts

| Category | Total Controls | Preventive | Detective | Auto-Remediated |
|----------|---------------|------------|-----------|-----------------|
| Organization | 2 | 2 | 0 | 0 |
| Logging | 2 | 2 | 0 | 0 |
| IAM/Identity | 5 | 3 | 2 | 1 |
| Network | 5 | 4 | 1 | 1 |
| S3 | 3 | 2 | 1 | 1 |
| EC2/EBS | 3 | 1 | 2 | 2 |
| RDS | 3 | 2 | 1 | 1 |
| Encryption | 1 | 1 | 0 | 0 |
| Detection | 4 | 0 | 4 | 0 |
| **Total** | **28** | **17** | **11** | **6** |

---

## Regulatory Coverage Summary

| Framework | Controls Covered | Coverage |
|-----------|-----------------|---------|
| NIST SP 800-53 Rev 5 | AC, AU, CA, CM, CP, IA, IR, RA, SA, SC, SI | Moderate+ baseline |
| SOC 2 Type II | CC1-CC9, A1, C1, PI1 | All TSC categories |
| HIPAA Security Rule | 164.308, 164.312 | Administrative + Technical safeguards |
| FFIEC CAT | D1, D2, D3, D4, D5 | All 5 domains at Baseline maturity |
