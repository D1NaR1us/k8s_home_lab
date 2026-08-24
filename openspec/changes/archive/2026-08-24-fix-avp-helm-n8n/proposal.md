## Why

The Argo CD Vault Plugin (AVP) is registered as a sidecar ConfigManagementPlugin, but the `n8n` Application uses `source.helm`, so Argo CD renders it with native Helm and never invokes AVP. The AVP-annotated Secrets ship with literal `<user>` / `<OPENAI_API_KEY>` placeholders, and n8n crash-loops on `getaddrinfo ENOTFOUND <host>` and `Invalid number value for DB_POSTGRESDB_PORT: <port>`. Hardcoding the AVP path (commit `38a4bce`) does not help — the Secret is still Helm-rendered and AVP is still never invoked. Plain-manifest apps (the `vault_test` example) resolve correctly.

## What Changes

- Deliver n8n's Secrets as plain AVP-annotated manifests in a single shared directory `ai_lab/defaults/custom_secrets`, one file per app (`n8n_secret.yaml` holds all of n8n's Secrets).
- Add a single Argo CD Application `ai-secrets` that points at that plain directory and runs it through the existing AVP plugin (`plugin.name: argocd-vault-plugin`); future AI apps add one more `<app>_secret.yaml` file, no new Application needed.
- `n8n_secret.yaml` contains two Secrets: `n8n-postgres-creds` (Vault path `kv/data/ai-apps/postgres`) and `n8n-tokens` (Vault path `kv/data/ai-apps/n8n-tokens`), both in the `ai-apps` namespace.
- Remove the `AI-postgres-secret.yaml` and `AI-tokens-secret.yaml` templates from `helm_ai` so the chart stops creating those Secrets (the Deployment's `secretKeyRef` injection stays, gated by the same `postgres.enabled`/`tokens.enabled` values).
- Leave the `n8n` Application single-source Helm and the AVP plugin / `tools/5-vault` config unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `ai-apps`: add a requirement that n8n's AVP-annotated Secrets resolve to real Vault values at sync time, so no literal `<...>` placeholder reaches the `ai-apps` namespace.

## Impact

- `ai_lab/defaults/custom_secrets/n8n_secret.yaml` — new plain manifest with n8n's Secrets (`n8n-postgres-creds`, `n8n-tokens`).
- `ai_lab/argocd_apps/apps/ai-secrets.yaml` — new Argo CD Application (plain directory, AVP plugin, dest namespace `ai-apps`).
- `ai_lab/defaults/helm_ai/templates/AI-postgres-secret.yaml` — removed.
- `ai_lab/defaults/helm_ai/templates/AI-tokens-secret.yaml` — removed.
- `ai_lab/defaults/helm_ai/values.yaml` — removed now-unused `postgres.avpPath` and `tokens.avpPath`.
- Runtime: sync `ai-secrets`; `n8n-postgres-creds` and `n8n-tokens` should hold real values and the n8n pod should become Healthy.
