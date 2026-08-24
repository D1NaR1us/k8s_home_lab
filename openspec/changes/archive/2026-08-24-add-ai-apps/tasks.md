## 1. Create the helm_ai chart

- [x] 1.1 Create `ai_lab/defaults/helm_ai/Chart.yaml` (name `helm-ai`, version 0.0.1)
- [x] 1.2 Create `ai_lab/defaults/helm_ai/values.yaml` with `namespace: ai-apps`, `container.image/port/env/resources/extraVolumeMounts`, `postgres.enabled: false` and `postgres.avpPath`, `tokens.enabled: false`, `tokens.avpPath` and `tokens.keys`
- [x] 1.3 Create `ai_lab/defaults/helm_ai/templates/AI-app.yaml` — Deployment in `.Values.namespace`, TZ env, container env from values, resource requests/limits from `container.resources`, shared PVC volume + extraVolumeMounts; when `postgres.enabled`, add DB env vars via `secretKeyRef` to the postgres creds Secret; when `tokens.enabled`, add token env vars via `secretKeyRef` to the tokens Secret
- [x] 1.4 Create `ai_lab/defaults/helm_ai/templates/AI-svc.yaml` — Service in `.Values.namespace`, selector `app: {{ .Release.Name }}-app`, port from values
- [x] 1.5 Create `ai_lab/defaults/helm_ai/templates/AI-ingress.yaml` — Traefik IngressRoute in `.Values.namespace`, `websecure`, host `{{ .Release.Name }}.home.lab`, service port named web
- [x] 1.6 Create `ai_lab/defaults/helm_ai/templates/AI-postgres-secret.yaml` — AVP-annotated Secret (keys host/port/database/user/password) when `postgres.enabled`, path from `postgres.avpPath`
- [x] 1.7 Create `ai_lab/defaults/helm_ai/templates/AI-tokens-secret.yaml` — AVP-annotated Secret (keys from `tokens.keys`, default `[OPENAI_API_KEY, N8N_ENCRYPTION_KEY]`) when `tokens.enabled`, path from `tokens.avpPath` (`kv/data/ai-apps/n8n-tokens`)

## 2. Create the AI storage (PV/PVC)

- [x] 2.1 Create `ai_lab/defaults/ai_pv_secret/AI-pv.yaml` — PV `ai-nfs` 15Gi, storageClass `nfs`, server `192.168.50.3`, path `/mnt/ai-apps`, RWX, mountOptions vers=3/nolock/tcp
- [x] 2.2 Create PVC `ai-claim` 15Gi in `ai-apps` ns binding to `ai-nfs` in the same file

## 3. Create the ArgoCD root app

- [x] 3.1 Create `ai_lab/argocd_apps/root_argocd/main.yaml` — root Application `main-ai-apps` watching `ai_lab/argocd_apps/apps`, project `default`, automated prune+selfHeal, `CreateNamespace=true`

## 4. Create the n8n application

- [x] 4.1 Create `ai_lab/argocd_apps/apps/n8n.yaml` — App `n8n`, dest ns `ai-apps`, source `ai_lab/defaults/helm_ai`, helm values: image `n8nio/n8n:latest`, port `5678`, env (WEBHOOK_URL, N8N_HOST/PROTOCOL/PORT, GENERIC_TIMEZONE), `container.resources` (requests 512Mi/250m, limits 2Gi/1), `postgres.enabled: true`, `tokens.enabled: true`, extraVolumeMount for `/home/node/.n8n` from `ai-claim`
- [x] 4.2 Add n8n entry (AI section) to `home_lab/defaults/helm_media/homepage-config/services.yaml`

## 5. External prerequisites (manual, one-time)

- [ ] 5.1 Create `/mnt/ai-apps` on NFS server `192.168.50.3` (owner: uid 1000, readable by cluster nodes)
- [ ] 5.2 Seed Vault: `vault kv put kv/data/ai-apps/postgres user=... password=... host=192.168.50.4 port=5432 database=...`
- [ ] 5.3 Seed Vault AI secrets: `vault kv put kv/data/ai-apps/n8n-tokens OPENAI_API_KEY=<your-token> N8N_ENCRYPTION_KEY=<random-32+bytes>` (keys must match `tokens.keys`)
- [ ] 5.4 Ensure n8n database/user exist on Postgres VM `192.168.50.4` and the k8s AVP role can read the `ai-apps` path

## 6. Verify

- [ ] 6.1 Push to `main`, confirm `main-ai-apps` root app appears in ArgoCD and `ai-apps` namespace is created
- [ ] 6.2 Confirm n8n app is Healthy/Synced and `https://n8n.home.lab` loads
- [ ] 6.3 Confirm n8n connected to Postgres (n8n logs show postgresdb, not SQLite) and data persists to `/mnt/ai-apps` across pod restart
- [ ] 6.4 Confirm n8n env exposes `OPENAI_API_KEY` + `N8N_ENCRYPTION_KEY` (from Vault) and an OpenAI test call succeeds — validates outbound egress to provider APIs
- [ ] 6.5 Confirm n8n pods report the configured CPU/memory requests and limits (e.g. `kubectl describe pod -n ai-apps`)
