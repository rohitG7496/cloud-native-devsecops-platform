# cloud-native-devsecops-platform
This Project demonstrates production-grade Cloud Native DevSecOps platform with automated Kubernetes provisioning (kubeadm + Ansible ) on EC2, Vault-based External secrets mgmt, ArgoCD GitOps deployments, Karpenter autoscaling on a self-managed kubernetes kubeadm based cluster, and enterprise CI/CD pipelines demonstrating real-world architecture and lifecycle automation.

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
