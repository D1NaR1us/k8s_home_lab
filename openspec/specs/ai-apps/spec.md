# ai-apps Specification

## Purpose
Deploys AI applications (n8n first) into the dedicated `ai-apps` namespace via a shared Helm chart, Traefik ingress on `*.home.lab`, shared NFS storage, and external Postgres from Vault, mirroring the home-media GitOps pattern.

## Requirements

### Requirement: Dedicated ai-apps namespace
All AI application workloads SHALL be deployed into the `ai-apps` Kubernetes namespace, kept separate from the `home-media` namespace.

#### Scenario: Workloads land in the right namespace
- **WHEN** any AI application (e.g. n8n) is deployed via ArgoCD
- **THEN** its Deployment, Service, and IngressRoute are created in the `ai-apps` namespace

#### Scenario: Namespace is created automatically
- **WHEN** the root application first syncs
- **THEN** the `ai-apps` namespace exists (created via `CreateNamespace=true`)

### Requirement: Shared Helm chart for AI apps
A single Helm chart SHALL provide the Deployment, Service, and Traefik IngressRoute for all AI applications, with per-app values supplied by each ArgoCD Application.

#### Scenario: New AI app from chart values
- **WHEN** a new ArgoCD Application points at the chart with custom image/port/volumes
- **THEN** the app is reachable at `https://<release-name>.home.lab` over `websecure`

### Requirement: Traefik ingress on home.lab
Each AI application SHALL be exposed via a Traefik IngressRoute using the `websecure` entrypoint and the host `https://<release-name>.home.lab`.

#### Scenario: HTTPS access to n8n
- **WHEN** a user opens `https://n8n.home.lab`
- **THEN** the request is routed to the n8n Service on its configured container port with TLS termination

### Requirement: Shared NFS storage
AI applications SHALL have access to persistent storage backed by the cluster NFS server, provisioned as a dedicated PV/PVC for AI apps (15Gi, intended for configs/workflow data — not for large files).

#### Scenario: Persistent data survives restarts
- **WHEN** a pod restarts
- **THEN** its configured data volume (e.g. `/home/node/.n8n`) is restored from the NFS-backed PVC

### Requirement: External Postgres for n8n
n8n SHALL use the existing external PostgreSQL VM (`192.168.50.4:5432`) as its database, with credentials injected from Vault via AVP annotations — no in-cluster database and no credentials in Git.

#### Scenario: Credentials come from Vault
- **WHEN** ArgoCD renders the n8n manifests
- **THEN** the Postgres host, port, database, user, and password are resolved from Vault via AVP, and the n8n container receives them as environment variables

#### Scenario: n8n uses Postgres not SQLite
- **WHEN** n8n starts with the AVP-resolved Postgres env vars
- **THEN** it connects to the external Postgres VM instead of the default SQLite database

### Requirement: Outbound network access to AI provider APIs
AI applications (n8n) SHALL be able to reach external AI provider APIs (e.g. OpenAI, Anthropic, Google) over HTTPS so AI workflows can call them.

#### Scenario: AI flow calls an external provider
- **WHEN** an n8n workflow invokes an external AI provider API (e.g. OpenAI)
- **THEN** the request reaches the provider over HTTPS and the response returns to n8n

#### Scenario: Egress is not blocked by network policy
- **WHEN** the `ai-apps` namespace is created
- **THEN** no NetworkPolicy exists that blocks outbound traffic from AI application pods

### Requirement: AI provider API tokens from Vault
AI-provider API tokens SHALL be injected into AI application containers as environment variables resolved from Vault via AVP annotations — never committed to Git.

#### Scenario: Tokens injected from Vault
- **WHEN** ArgoCD renders the n8n manifests with `tokens.enabled: true`
- **THEN** a Secret referencing Vault path `kv/data/ai-apps/n8n-tokens` is created and its keys (e.g. `OPENAI_API_KEY`) are exposed to the n8n container as environment variables

#### Scenario: Token values come from Vault, not Git
- **WHEN** the n8n manifests are inspected
- **THEN** no plaintext API token values appear in Git; values are placeholders replaced by AVP at sync time

### Requirement: n8n encryption key from Vault
n8n's `N8N_ENCRYPTION_KEY` (used to encrypt n8n's stored credentials) SHALL be resolved from Vault via AVP and injected as a container environment variable — never committed to Git.

#### Scenario: Encryption key injected from Vault
- **WHEN** ArgoCD renders the n8n manifests
- **THEN** `N8N_ENCRYPTION_KEY` is injected into the n8n container from the Vault path `kv/data/ai-apps/n8n-tokens`

#### Scenario: Encryption key value comes from Vault, not Git
- **WHEN** the n8n manifests are inspected
- **THEN** no plaintext encryption key appears in Git; the value is a placeholder replaced by AVP at sync time

### Requirement: Resource limits for AI applications
AI application containers SHALL run with explicit CPU/memory requests and limits defined via chart values, keeping workloads within the home cluster's constrained resources.

#### Scenario: Requests and limits applied
- **WHEN** an AI application (e.g. n8n) is deployed
- **THEN** its Deployment declares CPU/memory requests and limits sourced from the chart values

#### Scenario: Per-app overrides
- **WHEN** an ArgoCD Application provides custom `container.resources` values
- **THEN** those values override the chart defaults for that app

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
