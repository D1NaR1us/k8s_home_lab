# 2 - Install MetalLB 

This structure provides an overview of MetalLB, installation steps, usage, managing releases, customization, working with repositories, and a verification step. Adjust the commands and details based on your specific requirements and environment.

## 1. Purpose and Description of MetalLB

MetalLB (Metal Load Balancer) is a solution designed to provide load balancing capabilities in on-premises Kubernetes environments. In contrast to cloud providers that offer built-in load balancers, MetalLB allows the use of custom load balancing solutions, which is particularly crucial in local clusters.

## 2. Installing MetalLB

To install MetalLB, follow these steps:

```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml
```

## 3. Purpose of the metallb_config.yaml File
The [metallb_config.yaml](./metallb_conf.yaml) file contains the MetalLB configuration defining the range of IP addresses used for load balancing. You need apply it in your env.

```
kubectl apply -f metallb_conf.yaml
```

## 4. Verifying MetalLB Functionality
After installation and applying the configuration, you can verify the functionality of MetalLB by executing the following command:

```
kubectl get services -o wide
```
You will see external IP addresses provided by MetalLB for services with the LoadBalancer type.

> [!WARNING]
> Ensure that the `metallb_config.yaml` file contains the correct configuration for your network and environment.





