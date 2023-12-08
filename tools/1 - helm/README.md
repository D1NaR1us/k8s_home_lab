# 1 - Install Helm 

This structure provides an overview of Helm, installation steps, usage, managing releases, customization, working with repositories, and a verification step. Adjust the commands and details based on your specific requirements and environment.

## 1. Purpose and Description of Helm

Helm is a package manager for Kubernetes applications, simplifying the process of defining, installing, and upgrading even the most complex Kubernetes applications. It uses charts, which are packages of pre-configured Kubernetes resources, to streamline deployment workflows.
> [!INFO]
> You could read more about [Helm](https://helm.sh/docs/intro/install/)

## 2. Installing Helm

To install Helm, follow these steps:

### Download Helm binary
```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```
## 3. Using Helm Charts
Helm charts are used to package, version, and deploy applications to Kubernetes. To deploy an application using Helm, use the following command:


```
helm install [RELEASE_NAME] [CHART_NAME]

For example:
helm install my-release stable/mysql
This installs the MySQL chart from the official Helm chart repository.
```

## 4. Managing Helm Releases
Helm uses the concept of releases to manage deployed applications. You can list releases, upgrade, or uninstall them with the following commands:
```
List releases:
helm list

Upgrade a release:
helm upgrade [RELEASE_NAME] [CHART_NAME]

Uninstall a release:
helm uninstall [RELEASE_NAME]
```

## 5. Customizing Helm Charts
Helm charts often allow customization through values.yaml files. Create a custom values file and use it during installation:
```
helm show values [CHART_NAME] > default_values.yaml
helm install [RELEASE_NAME] [CHART_NAME] --values ./custom_default_values.yaml
helm upgrade --install [RELEASE_NAME] [CHART_NAME] --values ./custom_default_values.yaml -n [SOME_NAMESPACE]
```

## 6. Helm Repositories
Helm charts can be stored in repositories. To add a repository:
```
helm repo add [REPO_NAME] [REPO_URL]

For example:
helm repo add stable https://charts.helm.sh/stable
```

## 7. Verifying Helm Installation
Check Helm version:
```
helm version
```
This should display the Helm version and the Kubernetes version it is configured to interact with.