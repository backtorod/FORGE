# Security Policy

## Reporting a Vulnerability

**Do not open a public GitHub Issue for security vulnerabilities.**

If you discover a security vulnerability in FORGE — including issues in the Terraform modules, SCP policies, remediation Lambda code, or control matrix mappings — please report it responsibly.

### How to Report

Email: **security@forge-framework.io** *(placeholder — update with actual contact before publishing)*

Include:
- A description of the vulnerability
- Steps to reproduce / proof of concept
- The potential impact
- Any suggested remediation

### Response Timeline

| Phase | Target |
|---|---|
| Acknowledgment | Within 48 hours |
| Initial assessment | Within 5 business days |
| Fix or mitigation | Within 30 days for Critical/High |
| Public disclosure | Coordinated with reporter |

### Scope

In scope for this policy:
- All code in `modules/`, `remediation/`, `control-matrices/`, and `examples/`
- SCP policies that could create unintended privilege escalation
- Remediation Lambda functions that could be abused to modify infrastructure state

Out of scope:
- Issues in third-party dependencies (report upstream)
- AWS service vulnerabilities (report to AWS)

## Security of FORGE Deployments

FORGE is designed to *improve* the security posture of the environments it manages. The framework itself is subject to the same controls it enforces:
- All changes go through a peer-reviewed IaC pipeline
- Pre-commit hooks run Bandit and Checkov on every commit
- No credentials are ever committed to this repository
