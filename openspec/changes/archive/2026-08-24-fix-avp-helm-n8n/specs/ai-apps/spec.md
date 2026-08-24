## ADDED Requirements

### Requirement: Secrets resolved by AVP
n8n's AVP-annotated Secrets SHALL have their `<...>` placeholders replaced with values from Vault at sync time, so that no literal placeholder value reaches the `ai-apps` namespace.

#### Scenario: Secrets hold real values after sync
- **WHEN** the n8n Secrets are synced via AVP
- **THEN** the `n8n-postgres-creds` and `n8n-tokens` Secrets in the `ai-apps` namespace contain real values resolved from Vault

#### Scenario: No placeholder literals in the cluster
- **WHEN** the n8n Secrets are inspected in the cluster
- **THEN** none of their values is a literal `<...>` placeholder such as `<host>` or `<OPENAI_API_KEY>`

#### Scenario: n8n uses resolved credentials
- **WHEN** n8n starts with the resolved environment variables
- **THEN** it connects to the external Postgres VM instead of failing with a placeholder hostname or port
