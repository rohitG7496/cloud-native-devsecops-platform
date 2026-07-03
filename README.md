# cloud-native-devsecops-platform
This project demonstrates a production-grade Cloud Native DevSecOps platform with automated Kubernetes provisioning (kubeadm + Ansible) on AWS EC2, multi-master HA cluster architecture, External Secrets integration for fetching secrets from AWS Secrets Manager, ArgoCD GitOps deployments, Karpenter-based node autoscaling, HPA-driven application scaling, and enterprise CI/CD pipelines.

## Ansible Setup for HAProxy and Kubeadm

This project uses Ansible to automate the provisioning of the HAProxy Load Balancer and Kubernetes Control Plane dependencies.

### 1. Setup HAProxy (Load Balancer)
Edit the inventory/variables file to provide your infrastructure details:
```bash
vi Ansible/LB/all
```
Run the HAProxy playbook:
```bash
cd Ansible/LB
ansible-playbook -i all playbook.yml
```

### 2. Setup Kubernetes Control Plane (kubeadm)
Update the configuration variables for your control plane:
```bash
vi Ansible/cplane/all
```
Run the Control Plane playbook to install necessary components (kubelet, kubeadm, kubectl, containerd, etc.):
```bash
cd ../cplane
ansible-playbook -i all playbook.yml
```

### 3. Kubeadm Master Node Initialization
After the playbook completes successfully, initialize the Kubernetes control plane using the following command on master node:
```bash
sudo kubeadm init --control-plane-endpoint "<LB-PVT-IP>:6443" --upload-certs --apiserver-advertise-address="<pvt_of_master_node>" 
```

## HAProxy Monitoring

The HAProxy server is configured with a stats monitoring page on port `8404`.

### 1. Stats Access
You can access the stats page directly at `http://<LB-PVT-IP>:8404/stats`.
Use the credentials defined in [Ansible/LB/all](file:///Users/rohit_personal/Documents/cloud-native-devsecops-platform/Ansible/LB/all) (default: `admin:{{ haproxy_password }}`).

### 2. Nginx Reverse Proxy (SSL)
To expose the stats page via HTTPS with a domain, an Nginx configuration file is provided at `Ansible/LB/hproxy`. This includes SSL setup using Let's Encrypt certificates.

## Verification

### K8s High Availability (Master-Master)
After initializing the control plane and joining the second master node, you can verify that both master nodes are in the `Ready` state:
```bash
kubectl get nodes
```
![Master-Master HA](</images/master-master-HA.png>)

### 3. Monitoring Dashboard
Below is the HAProxy monitoring dashboard:
![HAProxy Monitoring](</images/HAProxy monitoring.png>)

## Install Add-ons
### EBS CSI Driver
IAM Permissions: Ensure your EC2 Worker Nodes have the AmazonEBSCSIDriverPolicy attached.
Install Driver (using local folder):
```bash
kubectl apply -k ebs-csi-driver
```

### Cert-Manager
Install cert-manager for certificate management:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
```

# Karpenter setup on Kubeadm Cluster

> **Note:** Previously, Karpenter was not officially supported on non-EKS clusters, but it now has **full support for self-managed Kubeadm clusters**.

## Karpenter Controller IAM Policy
To allow the Karpenter controller to provision nodes, you must attach the following IAM policy to your Kubeadm master node's IAM role:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Karpenter",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateFleet",
                "ec2:CreateLaunchTemplate",
                "ec2:CreateTags",
                "ec2:DeleteLaunchTemplate",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeImages",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceTypeOfferings",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeLaunchTemplates",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSpotPriceHistory",
                "ec2:DescribeSubnets",
                "ec2:RunInstances",
                "ec2:TerminateInstances",
                "ssm:GetParameter",
                "iam:PassRole",
                "pricing:GetProducts"
            ],
            "Resource": "*"
        }
    ]
}
```

## Setup Environment Variables for Karpenter
```
export CLUSTER_NAME="<YOUR-ClUSTER-NAME>"
export KARPENTER_VERSION="1.9.0" # Check for latest
export AWS_REGION="<AWS-REGION>"
export CLUSTER_ENDPOINT="<CLUSTER-ENDPOINT>" # Add your HAProxy PVT IP (eg. https://<HAProxy-PVT-IP>:6443)
```

## Install Karpenter
```
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace karpenter --create-namespace \
  --set settings.clusterName=${CLUSTER_NAME} \
  --set settings.clusterEndpoint=${CLUSTER_ENDPOINT} \
  --set settings.interruptionQueue="" \
  --set controller.resources.requests.cpu=200m \
  --set controller.resources.requests.memory=256Mi \
  --set dnsPolicy=Default \
  --set settings.featureGates.nodeRepair=false \
  --wait --timeout 5m
```

## Apply NodePool and EC2NodeClass
Apply the Karpenter configuration to define how worker nodes should be provisioned:
```bash
kubectl apply -f cloud-native-devsecops-platform/K8S/karpenter.yml
```

## Verification

### Karpenter Scaling Logs
You can observe the Karpenter controller logs to see it actively provisioning nodes when pods go into a `Pending` state:
```bash
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter -c controller
```
![Karpenter Scaling Logs](</images/karpenter-scaling-logs.png>)

### Scaled Nodes and Pods
Check the available nodes to see the newly provisioned instances joining the cluster. Then, verify that the pending pods are successfully scheduled and running on these new worker nodes:
```bash
kubectl get nodes
kubectl get po -n default -o wide
```
![Scaled Nodes and Pods](</images/scaled-nodes-pods.png>)

## CI/CD Tools Setup for DevSecOps
###  SonarQube Setup
Deploy SonarQube using the provided manifest:
```bash
kubectl apply -f sonarqube.yml
```
Storage: Uses storageClassName: ebs-sc (ensure this SC exists or update manifest to match your EBS CSI setup).
Access: https://sonar.jnrpro.solutions (Ensure DNS points to your Ingress Controller).

# External Secrets Operator Setup

To securely manage secrets like database passwords and API keys from AWS Secrets Manager, we use the External Secrets Operator.

## IAM Policy Requirements

To allow the External Secrets Operator to fetch secrets from AWS, you must attach the following IAM policy to your worker node's IAM role (or use IRSA):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetResourcePolicy",
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecretVersionIds"
            ],
            "Resource": "*"
        }
    ]
}
```

## Install External Secrets Operator

Add the Helm repository and install ESO:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets \
   external-secrets/external-secrets \
   -n external-secrets \
   --create-namespace \
   --set installCRDs=true \
   --wait
```

## Verify Installation

Ensure the External Secrets Operator pods are running successfully:

```bash
kubectl get po -n external-secrets
```
![External Secrets Pods](</images/external-secrets-pods.png>)

## Verify Secret Sync

Verify that the `ExternalSecret` resource is successfully connected and syncing secrets from AWS Secrets Manager:

```bash
kubectl get externalsecret aws-tradein -n tradein
```
![External Secret Sync Status](</images/external-secret-sync.png>)

## Verify Generated Secret

Verify the actual Kubernetes Secret created by ESO:

```bash
kubectl get secret tradein-secrets -n tradein -o yaml
```
![Generated Secret Status](</images/tradein-secrets-yaml.png>)

# AWS Load Balancer Controller (ALB Ingress Controller) Setup

This guide provides step-by-step instructions to install and configure the AWS Load Balancer Controller (ALB Ingress Controller) on the Kubernetes cluster.

## 1. Prerequisites
Before installing the AWS Load Balancer Controller, ensure you have:
* An active Kubernetes cluster running on AWS.
* `kubectl` installed and configured to communicate with the cluster.
* Necessary IAM privileges to manage IAM policies and roles in your AWS account.
* **Cert-Manager** installed in your cluster. The controller relies on cert-manager to generate certificate configurations for its webhooks.

## 2. Install Cert-Manager
Deploy the cert-manager manifest:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.3/cert-manager.yaml
```
Verify that the cert-manager pods are up and running:
```bash
kubectl get pods -n cert-manager
```

## 3. Required IAM Permissions
The AWS Load Balancer Controller requires IAM permissions to make calls to AWS APIs on your behalf.
1. Download the IAM policy document:
   ```bash
   curl -s -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
   ```
2. Create the IAM policy:
   ```bash
   aws iam create-policy \
       --policy-name AWSLoadBalancerControllerIAMPolicy \
       --policy-document file://iam_policy.json
   ```
   *Take note of the Policy ARN returned by this command.*

## 4. IAM Role & Service Account Configuration

For a self-managed **Kubeadm cluster on AWS EC2**, the controller inherits permissions directly from the AWS IAM Instance Profile attached to your EC2 instances (master/worker nodes).

### Step 1: Attach IAM Policy to the EC2 Instance Profile
1. Open the **AWS IAM Console** and locate the IAM Role associated with your Kubernetes EC2 instances.
2. Attach the `AWSLoadBalancerControllerIAMPolicy` created in the previous step to this IAM Role.

### Step 2: Service Account Verification
The installation manifest automatically creates the `aws-load-balancer-controller` Service Account in the `kube-system` namespace. There is no need to manually create or annotate it.


## 5. Download and Configure the Controller Manifest
1. Download the complete installation manifest:
   ```bash
   curl -sL https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.7.2/v2_7_2_full.yaml -o aws-alb-controller.yaml
   ```
2. Edit the manifest file to configure the controller with cluster-specific details. Open `aws-alb-controller.yaml` and locate the `Deployment` spec for `aws-load-balancer-controller` container arguments.
3. Update the container arguments to include your specific cluster details:
   ```yaml
               - --cluster-name=kubernetes
               - --aws-vpc-id=vpc-061e73c00667b2cae
               - --aws-region=ap-south-1
   ```
   **Explanation of configuration changes:**
   * `--cluster-name`: Specifies the name of your Kubernetes cluster (`kubernetes`).
   * `--aws-vpc-id`: Specifies the target AWS VPC ID where the load balancers will be created (`vpc-061e73c00667b2cae`).
   * `--aws-region`: Specifies the AWS region where your cluster resides (`ap-south-1`).

## 6. Controller Installation
Apply the modified manifest to your Kubernetes cluster:
```bash
kubectl apply -f aws-alb-controller.yaml
```

## 7. Verification Steps
1. Verify that the AWS Load Balancer Controller pods are running successfully:
   ```bash
   kubectl get deployment -n kube-system aws-load-balancer-controller
   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```
2. Check the controller logs to ensure there are no errors:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f
   ```
3. Test the setup by creating an Ingress resource utilizing the `alb` ingress class and ensure the controller provisions the AWS ALB resources as expected.
