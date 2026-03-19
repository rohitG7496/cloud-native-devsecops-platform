# cloud-native-devsecops-platform
This Project demonstrates production-grade Cloud Native DevSecOps platform with automated Kubernetes provisioning (kubeadm + Ansible ) on EC2, Vault-based External secrets mgmt, ArgoCD GitOps deployments, Karpenter autoscaling on a self-managed kubernetes kubeadm based cluster, and enterprise CI/CD pipelines demonstrating real-world architecture and lifecycle automation.

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
![Master-Master HA](<K8S /images/master-master-HA.png>)

### 3. Monitoring Dashboard
Below is the HAProxy monitoring dashboard:
![HAProxy Monitoring](<K8S /images/HAProxy monitoring.png>)

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
export CLUSTER_ENDPOINT="<CLUSTER-ENDPOINT>" # add your cluster endpoint
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
![Karpenter Scaling Logs](<K8S /images/karpenter-scaling-logs.png>)

### Scaled Nodes and Pods
Check the available nodes to see the newly provisioned instances joining the cluster. Then, verify that the pending pods are successfully scheduled and running on these new worker nodes:
```bash
kubectl get nodes
kubectl get po -n default -o wide
```
![Scaled Nodes and Pods](<K8S /images/scaled-nodes-pods.png>)
