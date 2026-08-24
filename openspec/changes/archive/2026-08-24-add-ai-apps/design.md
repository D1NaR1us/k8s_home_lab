## Context

The repo runs all media apps through one pattern: a generic Helm chart (`helm_media`) + one ArgoCD Application per app + a root app that watches the apps dir. See proposal.md for motivation. AI apps need the same workflow but isolated in a dedicated namespace (`ai-apps`), with their own storage quota and their own root app so the production media stack is untouched.

Existing infrastructure to reuse:
- NFS server `192.168.50.3` (media uses `/mnt/home-media`), storageClass `nfs`
- External Postgres VM `192.168.50.4:5432`, creds stored in Vault (`kv/home-media/postgres`)
- Vault + ArgoCD Vault Plugin (AVP) already wired — secrets resolved via `avp.kubernetes.io/path` annotations
- Traefik wildcard TLS cert covers `*.home.lab` (websecure)
- ArgoCD project `default`, self-heal + prune + `CreateNamespace=true`

## Goals / Non-Goals

**Goals:**
- New `ai_lab/` folder that structurally mirrors `home_lab/`
- New `ai-apps` namespace, dedicated 15Gi NFS PV/PVC, separate root ArgoCD app
- First app: n8n at `n8n.home.lab`, backed by external Postgres via Vault/AVP
- Chart is namespace-aware so future AI apps (ollama, open-webui, etc.) are drop-in

**Non-Goals:**
- No changes to `home_lab/` or the existing `main-home-media` root app
- No in-cluster Postgres for AI apps
- No SSL cert management (wildcard cert already covers n8n.home.lab)
- No backup/restore strategy for the AI PV (out of scope for learning setup)

## Decisions

### D1: New chart `helm_ai` (copy + adapt, not reuse `helm_media`)
Reuse `helm_media` templates but make them namespace-aware and drop media-specific hardcodes (`/data/downloads`, `/config` mounts, PUID/PGID, config.xml initContainer logic). Rationale: `helm_media` is tightly coupled to home-media paths; forcing AI apps through it would require refactoring the production chart. Alternative considered: parametrizing `helm_media` for both namespaces — rejected as higher risk to the live media stack.

Chart layout:
```
ai_lab/defaults/helm_ai/
├── Chart.yaml
├── values.yaml                    # namespace: ai-apps, container.*, postgres.*, tokens.*
└── templates/
    ├── AI-app.yaml                # Deployment (namespace from values, extraVolumeMounts, env)
    ├── AI-svc.yaml                # Service
    ├── AI-ingress.yaml            # IngressRoute, host {{ .Release.Name }}.home.lab
    ├── AI-postgres-secret.yaml    # AVP Secret when postgres.enabled
    └── AI-tokens-secret.yaml      # AVP Secret when tokens.enabled (AI-provider API keys)
```

### D2: Namespace as a chart value, default `ai-apps`
`values.yaml` sets `namespace: ai-apps`; all templates use `.Values.namespace`. The n8n ArgoCD App doesn't need to override it. Rationale: keeps template-level change minimal and lets a future app target a different namespace if ever needed.

### D3: External Postgres via AVP, not config.xml injection
`helm_media` uses an initContainer to inject Postgres into Sonarr's `config.xml`. n8n reads DB settings from **env vars** instead, so `helm_ai` takes a different path:
- `AI-postgres-secret.yaml` renders a Secret annotated with `avp.kubernetes.io/path` (configurable, default `kv/data/ai-apps/postgres`) with keys `host`, `port`, `database`, `user`, `password`.
- `AI-app.yaml`, when `postgres.enabled`, adds n8n DB env vars to the container via `valueFrom.secretKeyRef`:
  `DB_TYPE=postgresdb`, `DB_POSTGRESDB_HOST/PORT/DATABASE/USER/PASSWORD`.

Alternative considered: pointing AVP path at the existing `kv/home-media/postgres`. Rejected — AI apps should get their own Vault path (and ideally their own DB/db-user on the Postgres VM).

### D4: Dedicated 15Gi NFS PV/PVC for AI apps
New static PV/PVC in `ai_lab/defaults/ai_pv_secret/`:
- PV `ai-nfs`, 15Gi, storageClass `nfs`, server `192.168.50.3`, path `/mnt/ai-apps`, RWX, vers=3/nolock/tcp
- PVC `ai-claim`, 15Gi, in `ai-apps` ns, binds to `ai-nfs`

n8n mounts it at `/home/node/.n8n` (n8n config + workflow data) via `extraVolumeMounts`. Rationale: this PV holds configs/workflow data (text-sized, a few hundred MB), not large files, so 15Gi is ample while respecting the user's constrained disk. Alternative considered: reusing `hm-nfs` PV across namespaces — rejected (breaks the 200Gi quota accounting and mixes workloads).

### D5: Separate root ArgoCD app
New root app `main-ai-apps` at `ai_lab/argocd_apps/root_argocd/main.yaml`, source path `ai_lab/argocd_apps/apps`, destination `in-cluster` ns `argocd`. Rationale: isolated sync/status/rollback for AI apps; mirrors the existing `main-home-media` root app exactly.

### D6: n8n runtime config
- Image `n8nio/n8n:latest`, container port `5678`
- Env: `WEBHOOK_URL=https://n8n.home.lab/`, `N8N_HOST=n8n.home.lab`, `N8N_PROTOCOL=https`, `N8N_PORT=5678`, `GENERIC_TIMEZONE=Europe/Sofia`, `TZ=Europe/Sofia`
- The n8n official image runs as user `node` (uid 1000); PUID/PGID from the media chart are LinuxServer-isms and are NOT reused in `helm_ai`.
- Postgres env vars (D3) enable Postgres instead of SQLite.

### D7: Homepage dashboard entry (optional, low-effort)
Add an "AI" section with n8n link to `homepage-config/services.yaml` so it shows on the dashboard.

### D8: Outbound egress for AI provider APIs
The cluster has no NetworkPolicies today, so n8n pods get default allow-egress and can reach OpenAI etc. over HTTPS. Nothing extra to install. Action items: verify DNS egress at deploy time (n8n logs), and confirm the NUC nodes' firewall doesn't block outbound 443. Alternative considered: a dedicated NetworkPolicy — deferred, cluster-wide egress control is out of scope for this change.

### D9: AI-provider API tokens + n8n encryption key via AVP Secret + env injection
n8n stores credential values in its own DB, but for provider API keys the user wants them sourced from Vault so they never live in Git:
- `AI-tokens-secret.yaml` renders a Secret annotated `avp.kubernetes.io/path: kv/data/ai-apps/n8n-tokens` when `tokens.enabled`.
- Keys come from `tokens.keys` (default `[OPENAI_API_KEY, N8N_ENCRYPTION_KEY]`); keys in the manifest MUST match Vault keys. `N8N_ENCRYPTION_KEY` lives in the same Vault path — it encrypts n8n's stored credentials and must be stable across restarts.
- `AI-app.yaml` maps each key to a container env var via `valueFrom.secretKeyRef` against the `{{ .Release.Name }}-tokens` Secret. n8n workflows can then reference `$env.OPENAI_API_KEY` (or configure credentials pointing at the env var).

Alternative considered: storing provider keys as n8n credentials only (n8n DB) — rejected, user explicitly wants them in Vault/AVP.

### D10: Resource requests/limits in chart values
`helm_ai` defines `container.resources` (requests + limits) so pods are constrained for the home cluster. Chart defaults: requests `memory: 256Mi`, `cpu: 100m`; limits `memory: 1Gi`, `cpu: 500m`. The n8n App overrides via `container.resources` to realistic values for workflow runs (e.g. requests `512Mi`/`250m`, limits `2Gi`/`1`). Rationale: unlike home-media (requests only, limits commented out), AI apps need hard limits so a runaway workflow can't starve the NUC. Alternative considered: no limits — rejected, user explicitly asked for resource caps.

## Risks / Trade-offs

- **NFS path `/mnt/ai-apps` must exist on the server** → Mitigation: create the dir on `192.168.50.3` before first sync (task), matching how `/mnt/home-media` is already set up.
- **Vault path `kv/data/ai-apps/postgres` must be seeded** → Mitigation: one-time `vault kv put` (task), mirroring the documented `kv/home-media/postgres` setup; also register a k8s auth role if using pod-based AVP.
- **Vault path `kv/data/ai-apps/n8n-tokens` must be seeded before sync** → Mitigation: one-time `vault kv put kv/data/ai-apps/n8n-tokens OPENAI_API_KEY=<token> N8N_ENCRYPTION_KEY=<random-32+bytes>`; missing key makes AVP sync fail loudly (fail-safe). Keep `N8N_ENCRYPTION_KEY` stable — rotating it after n8n stores credentials makes them unreadable.
- **AVP placeholder rendering** → AVP templates use `<placeholder>` like existing examples; if Vault value missing, ArgoCD sync fails loudly (fail-safe).
- **Traefik wildcard host collision** → none expected: `n8n.home.lab` is not used by home-media.
- **`postgres.enabled` / `tokens.enabled` defaulting** → chart defaults `false`; the n8n App explicitly enables them so other AI apps aren't forced into Postgres/tokens.
- **Egress to external providers could be blocked by the NUC firewall** → Mitigation: verify at deploy time (task 6.3); only the node firewall could restrict, no cluster NetworkPolicies exist.
- **Two root apps syncing the same repo** → ArgoCD handles this fine; keep each root app scoped to its own apps dir to avoid cross-sync.

## Migration Plan

1. Create `ai_lab/` folder structure and `helm_ai` chart (D1/D2/D4).
2. Create root app + n8n app (D5/D6).
3. External prep (one-time, manual): create `/mnt/ai-apps` on NFS server; `vault kv put kv/data/ai-apps/postgres ...`; `vault kv put kv/data/ai-apps/n8n-tokens OPENAI_API_KEY=<token> N8N_ENCRYPTION_KEY=<random-32+bytes>`.
4. Push to `main` → ArgoCD syncs; root app `main-ai-apps` creates `ai-apps` ns, PV/PVC, and n8n.
5. Verify `https://n8n.home.lab` loads and Postgres connection succeeds (n8n logs / settings).
6. Rollback: `argocd app delete n8n` (or root app) removes the workload; PV/PVC/NFS data remain and can be re-attached.
