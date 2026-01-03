# 3 - Install ArgoCD 

Adjust the details based on your specific environment and preferences. This structure provides an introduction, installation steps, accessing the UI, deploying applications, managing applications through CLI, declarative configuration, rollback support, and verification steps for ArgoCD.

## 1. Purpose and Description of ArgoCD

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It helps to maintain and manage Kubernetes applications by using Git repositories as the source of truth for Kubernetes manifests.

## 2. Installing ArgoCD

To install ArgoCD, follow these steps:

```
# Create namespace for ArgoCD
kubectl create namespace argocd

# Install ArgoCD using the official Helm chart
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

To install ArgoCD with custom values in our environment run commands and paste into argocd_secret.yaml in base64 format

```
#admin.password
ARGO_PWD=<YourPassToLogin>
ARGO_PWD_ENCRYPTED=$(htpasswd -nbBC 10 "" $ARGO_PWD | tr -d ':\n' | sed 's/$2y/$2a/')
echo $ARGO_PWD_ENCRYPTED -n | base64 -w 0

#admin.passwordMtime
PASSWORD_dMtime=$(date -u +"%Y-%m-%dT%H:%M:%SZ" | tr -d '\n' | base64)
echo $PASSWORD_dMtime

#server.secretkey
Secret_Key=$(openssl rand -base64 32)
echo $Secret_Key
```

Now you may install (or upgrade) your helm

```
helm insatll argocd argo/argo-cd --values ./argo_values.yaml -n argocd
```

Now you able to login https://argocd.home.lab as admin with your password. Don't forget add IP for that resource to your DNS. IP should be traefik LB address.

> [!NOTE]
> <details><summary>Additional information how to work with ArgoCD</summary>
> 
> ### 1. Accessing ArgoCD UI
> To access the ArgoCD UI, you need to port forward to the ArgoCD server:
> 
> ```
> kubectl port-forward svc/argocd-server -n argocd 8080:443
> ```
> 
> Then, open your browser and navigate to https://localhost:8080. Log in using the default credentials (username: admin, password: password).
> 
> ### 2. Deploying Applications with ArgoCD
> ArgoCD deploys applications based on Git repositories. Define an application in a Git repository, and ArgoCD will automatically sync and deploy it.
> 
> ### 3. Managing Applications with ArgoCD CLI
> ArgoCD provides a command-line interface for managing applications. 
> 
> For example:
> ```
> List applications:
> argocd app list
> 
> Sync an application:
> argocd app sync [APP_NAME]
> 
> Delete an application:
> argocd app delete [APP_NAME]
> ```
> 
> ### 4. Declarative Application Configuration
> Define your application in a declarative manner using an Application CRD or a YAML file. This serves as the source of truth for your application state.
> 
> ### 5. ArgoCD Rollback
> ArgoCD supports rollbacks in case of issues with a deployed application:
> 
> ```
> argocd app rollback [APP_NAME]
> ```
> 
> ### 5. Verifying ArgoCD Installation
> Check the status of the ArgoCD components:
> 
> ```
> kubectl get all -n argocd
> ```
> 
> This should display the pods, services, and other components related to ArgoCD.
> 
> </details>