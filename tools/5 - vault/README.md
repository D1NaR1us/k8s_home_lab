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
helm install vault hashicorp/vault -n vault -f ./vault_values.yaml
```

---

## 3. Initialize & Unseal Vault
After the first install, manually initialize Vault and store the unseal keys safely.
```bash
kubectl exec -it vault-0 -n vault -- vault operator init
```


Copy the unseal keys, paste it to `vault_secret.yaml` and then manually apply that manifest into your  Kubernetes cluster
```bash
kubectl apply -f ./vault_secret.yaml -n vault
```

---

## 4. Unseal Vault
Now you may add `vault_unseal` dir to your active argocd and all necessery resources will be automatically created for you
