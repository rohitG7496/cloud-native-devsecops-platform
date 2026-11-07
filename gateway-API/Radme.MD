# 🚀 Envoy Gateway API + Let's Encrypt TLS on Bare-Metal EC2

Complete guide for deploying Envoy Gateway API, configuring Cert-Manager with Let's Encrypt (HTTP-01 challenges), and securely exposing Argo CD via HTTPS on a bare-metal Kubernetes cluster running on AWS EC2.

Because this setup runs on raw EC2 instances rather than a managed service (like EKS), it uses custom `EnvoyProxy` configurations to bypass cloud LoadBalancer requirements, along with DNS patches to resolve Hairpin NAT loops.

---

## 🧹 Prerequisites: Clean Slate

If migrating from an older Ingress controller (like AWS ALB or a static cert-manager manifest), remove all legacy webhooks, CRDs, and controllers before proceeding.

```bash
# Purge legacy static cert-manager resources
kubectl delete namespace cert-manager
kubectl get crd | grep cert-manager.io | awk '{print $1}' | xargs kubectl delete crd
kubectl delete validatingwebhookconfigurations cert-manager-webhook --ignore-not-found=true
kubectl delete mutatingwebhookconfigurations cert-manager-webhook --ignore-not-found=true
kubectl get clusterrole | grep cert-manager | awk '{print $1}' | xargs kubectl delete clusterrole
kubectl get clusterrolebinding | grep cert-manager | awk '{print $1}' | xargs kubectl delete clusterrolebinding
```

---

## Step 1: Install Envoy Gateway

Install the Envoy Gateway controller using the official Helm chart.

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.9.2 \
  --namespace envoy-gateway-system \
  --create-namespace
```

---

## Step 2: Configure Bare-Metal Envoy Proxy (IaC Fix)

By default, Envoy Gateway attempts to provision a Cloud LoadBalancer. On bare EC2, this fails. Fix this declaratively by forcing Envoy to use a `ClusterIP` service bound directly to the EC2 node's Private IP.

> 📄 Manifest: [`gateway-API/EnvoyProxy.yml`](./EnvoyProxy.yml)
>
> Before applying, update the `externalIPs` field in `EnvoyProxy.yml` with your worker node's permanent Private IP.

```bash
kubectl apply -f gateway-API/EnvoyProxy.yml
```

This creates two resources:
- **`EnvoyProxy`** — configures the Envoy service as `ClusterIP` with your node's private IP as `externalIPs`
- **`GatewayClass`** (`eg-ec2-class`) — links the Gateway API to this custom Envoy configuration

---

## Step 3: Install Cert-Manager (Gateway API Enabled)

Cert-Manager must be installed via Helm to properly configure RBAC permissions for the Kubernetes Gateway API.

```bash
# Add the Jetstack repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install with Gateway API features enabled
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.17.0 \
  --set crds.enabled=true \
  --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
  --set config.kind="ControllerConfiguration" \
  --set config.enableGatewayAPI=true
```

---

## Step 4: Fix Hairpin NAT (Let's Encrypt Self-Check)

When Cert-Manager attempts its internal HTTP-01 self-check, AWS VPC routing drops traffic destined for its own Public IP. Patch the deployment to force internal DNS lookups for your domain to resolve to the worker node's Private IP.

```bash
# Replace <EC2-PRIVATE-IP> with your worker node's private IP
# Replace <YOUR-DOMAIN> with your actual domain (e.g. argocd.example.com)
kubectl patch deployment cert-manager -n cert-manager --patch \
'{"spec": {"template": {"spec": {"hostAliases": [{"ip": "<EC2-PRIVATE-IP>", "hostnames": ["<YOUR-DOMAIN>"]}]}}}}'
```

---

## Step 5: Configure Let's Encrypt & Routing

### 5.1 Create the ClusterIssuer

Deploy a Let's Encrypt `ClusterIssuer` configured to use the `gatewayHTTPRoute` solver.

```yaml
# letsencryptissuer.yml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: your-email@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        gatewayHTTPRoute:
          parentRefs:
          - name: main-app-gateway
            namespace: default
            kind: Gateway
```

```bash
kubectl apply -f gateway-API/letsencryptissuer.yml
```

### 5.2 Apply the Gateway and HTTPRoute

> 📄 Manifest: [`gateway-API/agocd-ingress.yml`](./agocd-ingress.yml)

```bash
kubectl apply -f gateway-API/agocd-ingress.yml
```

This file creates three resources:
- **`Gateway`** (`main-app-gateway`) — listens on `:80` (HTTP-01 challenge) and `:443` (TLS termination), uses `eg-ec2-class`
- **`HTTPRoute`** (`argocd-route`) — routes traffic for your domain to the `argocd-server` service
- **`Certificate`** — instructs Cert-Manager to issue a Let's Encrypt certificate and store it as a Kubernetes Secret

Verify the certificate becomes ready:

```bash
kubectl get certificate -n default -w
# Wait for READY: True
```

---

## Step 6: Fix Argo CD Infinite Redirect Loop

Once TLS terminates at the Envoy Gateway, Argo CD triggers an `ERR_TOO_MANY_REDIRECTS` loop because its internal server expects HTTPS but receives HTTP from the proxy.

Disable Argo CD's internal TLS requirement so it trusts the Envoy Gateway as the TLS terminator:

```bash
# 1. Patch the ConfigMap to run Argo CD in insecure mode internally
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'

# 2. Restart the Argo CD server to apply the changes
kubectl rollout restart deployment argocd-server -n argocd
```

Argo CD is now securely accessible via HTTPS on your bare-metal cluster.

---

## Architecture Summary

```
Internet
   │
   ▼
EC2 Public IP  (DNS → your domain)
   │
   ▼
Envoy Gateway  (ClusterIP + externalIPs → EC2 Private IP)
   │
   ├── :80  ──► Cert-Manager HTTP-01 solver (Let's Encrypt challenge)
   │
   └── :443 ──► TLS Terminate → Argo CD Server (insecure mode)
```

| Component | Version | Notes |
|---|---|---|
| Envoy Gateway | v1.9.2 | Helm, bare-metal ClusterIP mode |
| Cert-Manager | v1.17.0 | Helm, Gateway API enabled |
| Let's Encrypt | ACME v2 | HTTP-01 via gatewayHTTPRoute |
| Argo CD | — | Insecure mode (TLS offloaded to Envoy) |
