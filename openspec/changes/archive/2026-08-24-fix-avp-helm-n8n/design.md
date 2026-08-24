## Context

AVP is registered as a sidecar CMP named `argocd-vault-plugin` (ConfigMap `avp-cmp-config` in `argocd`) whose `generate` is `argocd-vault-plugin generate .` with a `discover.find` that greps `.yaml` files for `avp.kubernetes.io`. Discovery runs only for plain-directory sources; a `source.helm` Application is rendered by native Helm and never triggers the plugin. The `n8n` Application uses `source.helm`, so its chart-generated Secrets keep literal `<...>` placeholders (confirmed live, and unchanged by hardcoding the path in commit `38a4bce`). See proposal.md - Why.

## Goals / Non-Goals

**Goals:**
- Deliver n8n's `n8n-postgres-creds` and `n8n-tokens` Secrets through the existing AVP plugin so they hold real Vault values (no `<...>` placeholders).
- Provide a single shared location + single Application so future AI apps only add one `<app>_secret.yaml` file.
- Keep the AVP plugin, the Helm chart's Deployment/Service/Ingress templates, and the `n8n` Application otherwise unchanged.

**Non-Goals:**
- Do not change any home_lab Application or the `helm_media` chart.
- Do not touch Vault data or the AVP plugin config.
- Do not introduce a combined Helm+AVP CMP, helm-in-sidecar, init-container injection, or a Helm secrets wrapper.

## Decisions

### 1. Plain AVP-annotated Secret manifests in a shared `custom_secrets` directory

Write n8n's Secrets as plain YAML (like `vault_test`) in `ai_lab/defaults/custom_secrets/`, one file per app (`n8n_secret.yaml`) containing all of that app's Secrets, each with a hardcoded `avp.kubernetes.io/path` and `<key>` placeholders:

```yaml
# ai_lab/defaults/custom_secrets/n8n_secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: n8n-postgres-creds
  namespace: ai-apps
  annotations:
    avp.kubernetes.io/path: "kv/data/ai-apps/postgres"
type: Opaque
stringData:
  user: <user>
  password: <password>
  host: <host>
  port: <port>
  database: <database>
---
apiVersion: v1
kind: Secret
metadata:
  name: n8n-tokens
  namespace: ai-apps
  annotations:
    avp.kubernetes.io/path: "kv/data/ai-apps/n8n-tokens"
type: Opaque
stringData:
  OPENAI_API_KEY: <OPENAI_API_KEY>
  N8N_ENCRYPTION_KEY: <N8N_ENCRYPTION_KEY>
```

- **Why**: the existing plugin already proves it resolves plain-manifest Secrets; unique per-app paths are hardcoded in each file, so no templating is needed. One file per app keeps the directory flat and predictable.
- **Alternatives considered**: combined Helm+AVP CMP (rejected — more infrastructure); committing literal values (rejected — puts secrets in Git); keeping the templates in Helm (rejected — AVP is never invoked for Helm sources); multi-source in the `n8n` app (works, but couples secrets to a single app and duplicates the source block per app).

### 2. Single shared `ai-secrets` Application (plain-directory source)

Add `ai_lab/argocd_apps/apps/ai-secrets.yaml` pointing at `ai_lab/defaults/custom_secrets` with `plugin.name: argocd-vault-plugin`, destination namespace `ai-apps`, and `CreateNamespace=true`. The root app `main-ai-apps` (watching `ai_lab/argocd_apps/apps`) auto-discovers it. The `n8n` Application stays single-source Helm.

- **Why**: one Application for all AI-app Secrets; adding a future app means dropping one more `<app>_secret.yaml` into the folder, not authoring a new Application. Explicit `plugin.name` runs AVP deterministically (more reliable than relying on `discover`).
- **Alternatives considered**: per-app Applications (rejected — N apps × M files to maintain); multi-source inside `n8n` (rejected — secrets would be tied to one app's source list).

### 3. Remove the secret templates from `helm_ai`

Delete `AI-postgres-secret.yaml` and `AI-tokens-secret.yaml` so the chart no longer creates those Secrets. The Deployment's `secretKeyRef` env injection (gated by `.Values.postgres.enabled` / `.Values.tokens.enabled`) stays and continues to reference the same Secret names, which now come from the plain manifests.

- **Why**: otherwise the chart and the plain manifests would both target the same Secret names and conflict.
- Remove the now-unused `postgres.avpPath` and `tokens.avpPath` values. Keep `tokens.keys` — the Deployment still iterates it to inject the token env vars.

### 4. Per-app Postgres secret (user decision)

Keep n8n's Postgres secret per-app (`n8n-postgres-creds`, path `kv/data/ai-apps/postgres`) rather than a shared home-media secret, matching the current chart values.

## Risks / Trade-offs

- [Sync ordering: Secrets vs Deployment] → two separate apps (`ai-secrets` and `n8n`); the n8n pod may briefly fail before the Secret exists and then recover. Optionally add a sync-wave or just rely on automated self-heal.
- [AVP must actually run on the plain directory] → explicit `plugin.name` avoids dependence on `discover`; still verify the Secret values after sync.
- [Name/path drift between plain manifests and the chart's `secretKeyRef`] → keep `n8n-postgres-creds` / `n8n-tokens` and the `ai-apps` namespace aligned; verify after sync.
- [Stale chart templates still creating Secrets] → removed in the same change; if left, Argo CD would report a resource conflict.
- [Plain manifests now contain `namespace: ai-apps`] → the `ai-secrets` app targets `ai-apps` with `CreateNamespace=true`, so this matches.

## Migration Plan

1. Add `ai_lab/defaults/custom_secrets/n8n_secret.yaml`.
2. Add `ai_lab/argocd_apps/apps/ai-secrets.yaml`.
3. Remove the two secret templates from `helm_ai` and prune `postgres.avpPath` / `tokens.avpPath` from `values.yaml`.
4. Push; the `main-ai-apps` root app registers `ai-secrets`; sync it.
5. Verify `n8n-postgres-creds` / `n8n-tokens` hold real values and the n8n pod is Healthy.
6. Rollback: delete `ai-secrets.yaml` and the `custom_secrets` directory, restore the deleted templates.

## Open Questions

None.
