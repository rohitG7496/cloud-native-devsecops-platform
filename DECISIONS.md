# Architecture Decision Log

This document records the major architectural choices made for this Cloud Native DevSecOps platform and the rationale behind them.

## 1. Self-Managed Kubernetes vs. Managed EKS

**Decision:** Provision a highly available, self-managed Kubernetes cluster on AWS EC2 instead of relying on Amazon EKS.

**Reasoning:**
*   **Cost Reduction:** Amazon EKS imposes a fixed overhead fee of roughly $73 per month solely for managing the cluster's control plane, on top of standard EC2 compute costs for worker nodes. Building a self-managed cluster eliminates this baseline expense entirely—a critical cost-saving factor, especially when maintaining multiple environments (e.g., Development, Staging, Production).
*   **Architectural Freedom:** A self-hosted approach unboxes the control plane, yielding fine-grained authority over the cluster's foundational layers. It enables us to handpick and inject custom Container Network Interfaces (CNIs), specialized Container Storage Interfaces (CSIs), and rigorous Network Policies that might otherwise be constrained or abstracted away by a managed provider.

## 2. Karpenter vs. Kubernetes Cluster Autoscaler 

**Decision:** Utilize Karpenter for node auto-scaling instead of the traditional Kubernetes Cluster Autoscaler.

**Reasoning:**
*   **Just-In-Time Provisioning:** The legacy Cluster Autoscaler fundamentally relies on pre-configured Auto Scaling Groups (ASGs), making it slow and incapable of true just-in-time scaling. Karpenter entirely circumvents ASGs, communicating directly with the EC2 Fleet API to spin up precisely sized nodes in milliseconds.
*   **Dynamic Cost Optimization:** Rather than scaling rigid instance groups, Karpenter intelligently analyzes the resource requests of pending pods and dynamically provisions the most cost-effective and highly available compute options on the market at that exact moment (including Spot instances or flexible instance families like `c7i-flex`).
*   **Broader Ecosystem Support:** While Karpenter was originally engineered exclusively for EKS, it has since matured to offer first-class support for self-hosted clusters. This allows us to bring enterprise-grade EKS scaling capabilities to our custom, cost-effective EC2 architecture.

## 3. External Secrets Operator vs. Native Kubernetes Secrets

**Decision:** Store sensitive material (e.g., Database credentials) in AWS Secrets Manager and utilize the External Secrets Operator (ESO) to sync them into the cluster.

**Reasoning:**
*   **Enhanced Security:** Native Kubernetes Secrets are merely base64 encoded by default. AWS Secrets Manager offers robust KMS-backed encryption at rest and strict IAM validation before any secret can be read.
*   **Declarative GitOps:** Hardcoding API keys or passwords into YAML files is a critical security violation. ESO bridges this gap, allowing us to maintain 100% declarative infrastructure in Git while dynamically securely injecting the actual credentials inside the cluster at runtime.

## 4. AWS Load Balancer Controller vs. NGINX Ingress

**Decision:** Use the AWS Load Balancer Controller to manage Ingress resources via native AWS Application Load Balancers (ALBs).

**Reasoning:**
*   **Native AWS Security Integration:** Utilizing an ALB immediately unlocks native integrations with AWS Web Application Firewall (WAF) and AWS Shield, allowing us to scrub malicious traffic (like SQL injection or DDoS attempts) at the edge of the VPC, long before it reaches the Kubernetes nodes.
*   **Optimized Routing:** The controller configures the ALB to route inbound web traffic directly to the private IPs of the pods, stripping away the latency and overhead of internal proxy layers like `kube-proxy`.