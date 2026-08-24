## Why

The `home_lab` folder proves a solid GitOps pattern (single Helm chart + Traefik IngressRoute + ArgoCD apps) for media apps. The user wants the same workflow for AI applications, starting with n8n, to learn and prototype AI flows. A separate folder keeps AI experiments isolated from the production media stack (dedicated namespace, disk quota, root app).

## What Changes

- New top-level folder `ai_lab/` mirroring the `home_lab/` structure:
  - `ai_lab/defaults/helm_ai/` — Helm chart (Deployment, Service, Traefik IngressRoute, optional Postgres secret via AVP)
  - `ai_lab/defaults/ai_pv_secret/` — 15Gi PV/PVC on the existing NFS server
  - `ai_lab/argocd_apps/root_argocd/main.yaml` — **separate** root app watching `ai_lab/argocd_apps/apps`
  - `ai_lab/argocd_apps/apps/n8n.yaml` — first application
- New Kubernetes namespace `ai-apps` (created via ArgoCD `CreateNamespace=true`).
- n8n deployed at `n8n.home.lab` (websecure, wildcard TLS cert already covers `*.home.lab`).
- n8n uses the **existing external Postgres VM** (`192.168.50.4:5432`) instead of bundled storage; credentials resolved from Vault via AVP.
- n8n has **outbound network access** to external AI provider APIs (OpenAI, etc.) to build and run AI flows.
- AI-provider **API tokens are stored in Vault** (`kv/data/ai-apps/n8n-tokens`) and injected as container env vars via AVP — never in Git.
- n8n's **`N8N_ENCRYPTION_KEY`** (used to encrypt n8n's own stored credentials) is also sourced from Vault via AVP, alongside the provider tokens.
- n8n gets explicit **resource requests/limits** (configurable per app in chart values) to fit the constrained home cluster.
- Chart templates parametrized on `namespace` (default `ai-apps`) so future AI apps are just new ArgoCD Apps, same as home-media.

## Capabilities

### New Capabilities
- `ai-apps`: Deploying AI applications (n8n first) into the `ai-apps` namespace via the shared `helm_ai` chart, with Traefik `*.home.lab` ingress, shared NFS storage, and external Postgres from Vault.

### Modified Capabilities
- none

## Impact

- **New folder**: `ai_lab/` (does not touch `home_lab/`).
- **Helm**: new chart `helm_ai` (copy/adaptation of `helm_media`, namespace-aware).
- **ArgoCD**: one new root Application + one app `n8n`; existing root app `main-home-media` is untouched.
- **Storage**: new 15Gi NFS PV/PVC (config-only storage, not for large files); NFS server `192.168.50.3` must expose a path for AI apps (e.g. `/mnt/ai-apps`).
- **Secrets**: n8n Postgres creds expected in Vault (AVP path), reusing the existing Vault/AVP setup; AI-provider API tokens + `N8N_ENCRYPTION_KEY` in a dedicated Vault path `kv/data/ai-apps/n8n-tokens`.
- **Network**: n8n requires outbound HTTPS egress to external AI provider APIs.
- **Resources**: n8n pods run with explicit requests/limits defined in chart values (home cluster constraints).
- **DNS**: `n8n.home.lab` must resolve to the Traefik LB IP (wildcard already configured).
