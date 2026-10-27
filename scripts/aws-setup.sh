#!/usr/bin/env bash
# ==============================================================================
# Script: aws-setup.sh
# Purpose: Automated provisioning of AWS ECR, EKS Cluster, Node Group,
#          AWS Load Balancer Controller, and Metrics Server in ap-south-1.
# ==============================================================================

set -euo pipefail

# ----------------- Configuration Variables -----------------
AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-cems-cluster}"
ECR_REPO_NAME="${ECR_REPO_NAME:-cems-app}"
K8S_VERSION="${K8S_VERSION:-1.30}"
NODE_TYPE="${NODE_TYPE:-t3.medium}"
NODE_COUNT="${NODE_COUNT:-2}"
MIN_NODES="${MIN_NODES:-2}"
MAX_NODES="${MAX_NODES:-4}"

echo "=========================================================="
echo " Starting AWS Cloud Infrastructure Provisioning for CEMS"
echo " Region:       ${AWS_REGION}"
echo " Cluster:      ${CLUSTER_NAME}"
echo " Node Type:    ${NODE_TYPE} (Min: ${MIN_NODES}, Max: ${MAX_NODES})"
echo "=========================================================="

# Check AWS authentication
echo "[1/6] Verifying AWS CLI credentials..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Authenticated as AWS Account: ${AWS_ACCOUNT_ID}"

# 1. Create ECR Repository
echo "[2/6] Creating Amazon ECR Repository: ${ECR_REPO_NAME}..."
if aws ecr describe-repositories --repository-names "${ECR_REPO_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "ECR repository '${ECR_REPO_NAME}' already exists."
else
    aws ecr create-repository \
        --repository-name "${ECR_REPO_NAME}" \
        --region "${AWS_REGION}" \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256
    echo "ECR repository created successfully."
fi

# 2. Provision EKS Cluster using eksctl
echo "[3/6] Provisioning Amazon EKS Cluster with managed node group..."
if eksctl get cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "EKS Cluster '${CLUSTER_NAME}' already exists."
else
    eksctl create cluster \
        --name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --version "${K8S_VERSION}" \
        --nodegroup-name "cems-nodes" \
        --node-type "${NODE_TYPE}" \
        --nodes "${NODE_COUNT}" \
        --nodes-min "${MIN_NODES}" \
        --nodes-max "${MAX_NODES}" \
        --managed \
        --with-oidc
    echo "EKS cluster created successfully."
fi

# 3. Configure kubectl context
echo "[4/6] Updating local kubeconfig..."
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"
kubectl get nodes

# 4. Install Kubernetes Metrics Server (Required for HorizontalPodAutoscaler)
echo "[5/6] Deploying Kubernetes Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 5. Setup AWS Load Balancer Controller
echo "[6/6] Installing AWS Load Balancer Controller..."
# Download IAM policy for AWS Load Balancer Controller
curl -sS -o /tmp/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.8.1/docs/install/iam_policy.json

# Create IAM policy if not exists
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
if ! aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
    aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file:///tmp/iam_policy.json
fi

# Associate IAM ServiceAccount
eksctl create iamserviceaccount \
    --cluster="${CLUSTER_NAME}" \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --role-name="AmazonEKSLoadBalancerControllerRole" \
    --attach-policy-arn="${POLICY_ARN}" \
    --approve \
    --override-existing-serviceaccounts

# Install Controller via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --query "cluster.resourcesVpcConfig.vpcId" --output text)

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName="${CLUSTER_NAME}" \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region="${AWS_REGION}" \
    --set vpcId="${VPC_ID}"

echo "=========================================================="
echo " AWS Cloud Infrastructure Setup Complete!"
echo " ECR Registry: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
echo " EKS Cluster:  ${CLUSTER_NAME}"
echo "=========================================================="
