## 1. Create plain AVP-annotated Secret manifests

- [x] 1.1 Create `ai_lab/defaults/custom_secrets/n8n_secret.yaml` with two Secrets: `n8n-postgres-creds` (`avp.kubernetes.io/path: kv/data/ai-apps/postgres`, keys `user`/`password`/`host`/`port`/`database`) and `n8n-tokens` (`avp.kubernetes.io/path: kv/data/ai-apps/n8n-tokens`, keys `OPENAI_API_KEY`/`N8N_ENCRYPTION_KEY`), both in `ai-apps`, with `<key>` placeholders

## 2. Add the shared ai-secrets Application

- [x] 2.1 Create `ai_lab/argocd_apps/apps/ai-secrets.yaml` — Application `ai-secrets`, source path `ai_lab/defaults/custom_secrets` with `plugin.name: argocd-vault-plugin`, destination namespace `ai-apps`, automated prune/selfHeal, `CreateNamespace=true`

## 3. Stop the chart from creating the Secrets

- [x] 3.1 Delete `ai_lab/defaults/helm_ai/templates/AI-postgres-secret.yaml`
- [x] 3.2 Delete `ai_lab/defaults/helm_ai/templates/AI-tokens-secret.yaml`
- [x] 3.3 Remove now-unused `postgres.avpPath` and `tokens.avpPath` from `ai_lab/defaults/helm_ai/values.yaml` (keep `tokens.keys`)

## 4. Deploy and verify

- [x] 4.1 Push to `main` and confirm the `main-ai-apps` root app registers `ai-secrets` and it syncs
- [x] 4.2 Confirm `n8n-postgres-creds` and `n8n-tokens` in `ai-apps` hold real values (no `<...>` placeholders)
- [ ] 4.3 Confirm the n8n pod is Healthy, connects to Postgres (logs show `postgresdb`, not SQLite), and exposes `OPENAI_API_KEY` / `N8N_ENCRYPTION_KEY`
