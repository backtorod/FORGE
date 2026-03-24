# FORGE — Example: Regulated Enterprise

> **Status: Placeholder** — Coming in v0.3.0.
>
> This example will cover large enterprises (500+ employees) operating under
> **FFIEC CAT** (banking/fintech) or **HIPAA** (healthcare) mandates:
>
> - AWS GovCloud (US) compatibility layer
> - FedRAMP Moderate baseline alignment
> - Dedicated compliance account per regulatory body
> - HITRUST/HIPAA-specific Config rules and Security Hub standards
> - FFIEC CAT domain-by-domain automated evidence collection
> - Customer-managed HSM key material via AWS CloudHSM
> - Cross-account EventBridge bus for centralized SIEM integration
> - Pager Duty / ServiceNow webhook remediation pipeline
> - Network Firewall + Gateway Load Balancer for east-west inspection
> - AWS Audit Manager with custom FORGE assessment framework

In the meantime, start with the [baseline-regulated example](../baseline-regulated/)
and review the [control matrices](../../control-matrices/) for HIPAA and
FFIEC mapping coverage.
