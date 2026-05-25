# 4 - Install HashiCorp Vault + ArgoCD Vault Plugin

This guide helps you install Vault in a secure and GitOps-friendly way in a home Kubernetes cluster using Helm, Traefik Ingress, and ArgoCD Vault Plugin (AVP).

## 1. Purpose and Description

**HashiCorp Vault** is a tool for securely accessing secrets and encrypting data.  
**ArgoCD Vault Plugin (AVP)** allows injecting secrets from Vault into your Kubernetes manifests managed by ArgoCD — without storing sensitive values in Git.

---

## 2. Installing Vault with Helm

```bash
# Add HashiCorp Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Create namespace
kubectl create namespace vault

# Install local-path-storage which will be used by vault
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml


# Install Vault using Helm and custom values
helm install vault hashicorp/vault -n vault -f ./vault/vault_values.yaml
```

---

## 3. Initialize Vault
After the first install, manually initialize Vault and store the unseal keys safely.
```bash
kubectl exec -it vault-0 -n vault -- vault operator init
```

---

## 4. Unseal cronJob Vault
Copy the unseal keys, paste it to `vault/vault_unsealed_secret.yaml` and then manually apply that manifest into your  Kubernetes cluster
```bash
kubectl apply -f ./vault/vault_unseal_secret.yaml
```

After that you should apply CronJob which will track unseal status of your vault.

```bash
kubectl apply -f ./vault/vault_unseal_cronjob.yaml
```

---

## 5. Enable Vault WebUI
In case if you want use WebUI of Vault apply that manifest

```bash
kubectl apply -f ./vault/vault_ingress.yaml
```

---

## 6. Enable Vault:Kubernetes auth

```bash
kubectl exec -it vault-0 -n vault -- vault auth enable kubernetes
kubectl exec -it vault-0 -n vault -- vault write kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/argocd \
  bound_service_account_names=argocd-repo-server \
  bound_service_account_namespaces=argocd \
  policies=my-app-policy \
  ttl=1h
```

---

## 7. Enable KV2 v2 and create a policy
```bash
kubectl exec -it vault-0 -n vault -- vault secrets enable -path=kv kv-v2
kubectl exec -it vault-0 -n vault -- vault policy write my-app-policy ./vault/vault_policy.hcl
```


## 8. Apply all manifests from ./argocd_plugin dir
Now you may apply all manifests from the ./argocd_plugin dir.
```bash
kubectl apply -f ./argocd_plugin/avp_plugin.yaml

kubectl apply -f ./argocd_plugin/avp_rbac.yaml

kubectl apply -f ./argocd_plugin/vault_config_secret.yaml

helm upgrade argocd argo/argo-cd -n argocd -f ./argocd_plugin/argocd_values.yaml
```

## 9. Store Postgres credentials for home-media apps (sonarr/radarr)
One-time setup. Run inside the vault pod. Credentials are stored in Vault only -- never in git.
```bash
kubectl exec -it vault-0 -n vault -- /bin/sh

# Inside the vault pod:
vault login   # use your root token or admin token

vault kv put kv/home-media/postgres \
  user=postgres \
  password=<YOUR_POSTGRES_PASSWORD> \
  host=192.168.50.4 \
  port=5432

# Verify:
vault kv get kv/home-media/postgres
exit
```

Then register the home-media Kubernetes auth role so init containers can authenticate:
```bash
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/home-media \
  bound_service_account_names=home-media-sa \
  bound_service_account_namespaces=home-media \
  policies=my-app-policy \
  ttl=15m
```

How it works at runtime:
  1. Pod starts, init container runs before sonarr/radarr
  2. Init container authenticates to Vault using the pod's K8s ServiceAccount JWT
  3. Fetches user/password/host/port from kv/home-media/postgres
  4. If config.xml missing  -> creates it with Postgres block
  5. If config.xml exists   -> injects Postgres block before </Config>
  6. If Postgres block already there -> skips (idempotent, safe on pod restarts)
  7. Main container starts, config.xml is ready

