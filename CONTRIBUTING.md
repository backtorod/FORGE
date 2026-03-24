# Contributing to FORGE

Thank you for contributing to FORGE. This document describes the governance process for all contributions.

## Issue First Policy

All proposed changes must be preceded by a GitHub Issue describing the problem or enhancement before any code is submitted. This ensures alignment before investment.

## Contribution Types

### Bug Fixes
Open an issue with label `bug`, describe the incorrect behavior and expected behavior, then open a PR referencing the issue.

### New Controls / SCP Policies
All Control Matrix or SCP additions require:
1. A cited regulatory reference (NIST control ID, FFIEC domain, SOC 2 criterion, or HIPAA section)
2. Peer review by at least **two maintainers** before merge
3. Corresponding test in `tests/compliance/`
4. Updated YAML entry in the relevant `control-matrices/` subdirectory

### Remediation Modules
All remediation Lambda changes require:
1. Automated security scanning via Bandit (Python) and Checkov (Terraform) passing in CI
2. A unit test in `tests/remediation/` covering the happy path and at least one error condition
3. MTTR benchmark documented in the module README

### Documentation
Documentation PRs do not require security review but must be accurate and cite sources for any regulatory claims.

## Breaking Changes

Breaking changes to module interfaces (variable renames, removed outputs, changed resource types) require:
- A major version increment in `CHANGELOG.md`
- A documented migration path in `docs/migration/`
- A deprecation notice in the previous minor version

## Security Vulnerabilities

Do **not** open a public issue for security vulnerabilities. Follow the process in [SECURITY.md](SECURITY.md).

## Code Style

- **Terraform**: Enforced via `terraform fmt`. Run `pre-commit run --all-files` before submitting.
- **Python**: Enforced via `black`. Line length 100.
- **YAML control matrices**: Follow the schema defined in `control-matrices/README.md`.

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) format:
```
feat(scp): add deny-public-rds-snapshot policy
fix(remediation/s3): handle missing bucket name gracefully
docs(deployment-guide): add Phase 2 prerequisites
```

## Code of Conduct

All contributors are expected to maintain professional, respectful communication. Violations will result in removal from the project.
