# Install Traefik

These instructions guide you through installing Traefik using Helm, generating a self-signed certificate, creating a Kubernetes secret for it, and configuring Traefik to use the self-signed certificate for TLS. Adjust the details based on your specific domain and requirements.

## 1. Purpose and Description of Traefik

Traefik is a modern, dynamic, and flexible reverse proxy and load balancer that integrates seamlessly with Kubernetes. It simplifies the process of managing ingress traffic and provides features such as automatic SSL certificate provisioning and dynamic configuration.
> [!INFO]
> You could read more about [Traefik](https://doc.traefik.io/traefik/v2.10/)

## 2. Using Self-Signed Certificate
Create a self-signed certificate for your domain. You can use tools like OpenSSL to generate a self-signed certificate and key.

These commands collectively generate a CA, a certificate, and a private key, sign the certificate, and organize them into a full chain certificate with additional configuration for Subject Alternative Names.

```bash
# Generate CA Key Pair:
openssl genrsa -aes256 -out ./SSL_Certs/ca-key.pem 4096
# This command generates a new RSA private key for the Certificate Authority (CA) with AES encryption and saves it to ./SSL_Certs/ca-key.pem with a key length of 4096 bits.

# Create CA Certificate:
openssl req -new -x509 -sha256 -days 3650 -key ./SSL_Certs/ca-key.pem -out ca.pem
# This command creates a self-signed X.509 CA certificate valid for 3650 days using the previously generated CA private key. The certificate is saved to ./SSL_Certs/ca.pem.

# Generate Certificate Key Pair:
openssl genrsa -out ./SSL_Certs/cert-key.pem 4096
# This command generates a new RSA private key for the certificate without encryption and saves it to ./SSL_Certs/cert-key.pem with a key length of 4096 bits.

# Create Certificate Signing Request (CSR):
openssl req -new -sha256 -subj "/CN=home-media" -key ./SSL_Certs/cert-key.pem -out ./SSL_Certs/cert.csr
# This command creates a Certificate Signing Request (CSR) for the specified Common Name (CN) "home-media" using the private key. The CSR is saved to ./SSL_Certs/cert.csr.

# Generate Subject Alternative Name (SAN) Extension File:
echo "subjectAltName=DNS:*.home.lab,IP:<IP_LB_Traefik>" >> ./SSL_Certs/extfile.cnf
# This command appends the Subject Alternative Name (SAN) extension to the extfile.cnf file, including DNS names and an IP address. Make sure to replace <IP_LB_Traefik> with the actual IP address of your Traefik Load Balancer.

# Sign the Certificate Using CA:
openssl x509 -req -sha256 -days 3650 -in ./SSL_Certs/cert.csr -CA ./SSL_Certs/ca.pem -CAkey ./SSL_Certs/ca-key.pem -out ./SSL_Certs/cert.pem -extfile ./SSL_Certs/extfile.cnf -CAcreateserial
# This command signs the certificate using the CA, creating a new X.509 certificate valid for 3650 days. The signed certificate is saved to ./SSL_Certs/cert.pem.

# Create Full Chain Certificate:
cat ./SSL_Certs/cert.pem > ./SSL_Certs/final_keys/fullchain.pem
cat ./SSL_Certs/ca.pem >> ./SSL_Certs/final_keys/fullchain.pem 
# This command concatenates the signed certificate (cert.pem) and the CA certificate (ca.pem) to create a full chain certificate (fullchain.pem). The full chain certificate is saved to ./SSL_Certs/final_keys/fullchain.pem.

# Move Certificate Key to Final Location:
mv ./SSL_Certs/cert-key.pem ./SSL_Certs/final_keys/cert-key.pem
# This command moves the private key (cert-key.pem) to the final keys directory (./SSL_Certs/final_keys/cert-key.pem), ensuring it is securely stored.
```

Then, you could create a Kubernetes secret with the generated certificate manually, or add generated certificats into the [traefik_value.yaml](./traefik_values.yaml) in part `extraObjects:`

before you will add this files, you have to keep it in base64 format
```
cat ./SSL_Certs/final_keys/fullchain.pem | base64
cat ./SSL_Certs/final_keys/cert-key.pem | base64
```

Example of `extraObjects:` part
```
extraObjects:
  - apiVersion: v1
    kind: Secret
    metadata:
      name: traefik-secret-tls
    type: kubernetes.io/tls
    data:
      tls.crt: <base64-encoded-fullchain.pem-data>
      tls.key: <base64-encoded-cert-key.pem-data>
```

## 3. Installing Traefik with Helm

To install Traefik using Helm, follow these steps:

```bash
# Add the Traefik Helm repository
helm repo add traefik https://helm.traefik.io/traefik

# Update the Helm repositories
helm repo update

# Create a namespace for Traefik
kubectl create namespace traefik

# Install Traefik with Helm
helm install traefik traefik/traefik --values ./traefik_values.yaml -n traefik
```
This installs Traefik in the traefik namespace using Helm.

## 4. Monitoring Traefik
Traefik comes with a dashboard that provides insights into the routing and traffic. Now you able to login https://traefik.home.lab. Don't forget add IP for that resource to your DNS. IP should be traefik LB address.
