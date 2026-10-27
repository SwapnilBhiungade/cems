#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-eks.sh
# Purpose: Builds the CEMS Docker image, pushes to ECR with Git SHA tag,
#          and deploys to the Amazon EKS cluster.
# ==============================================================================

set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-cems-cluster}"
ECR_REPO_NAME="${ECR_REPO_NAME:-cems-app}"
K8S_NAMESPACE="${K8S_NAMESPACE:-cems}"

GIT_TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "v1.0.0")
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${ECR_REGISTRY}/${ECR_REPO_NAME}:${GIT_TAG}"

echo "=========================================================="
echo " Deploying CEMS to Amazon EKS"
echo " Image:   ${IMAGE_URI}"
echo " Cluster: ${CLUSTER_NAME}"
echo "=========================================================="

# 1. Login to Amazon ECR
echo "[1/5] Logging into Amazon ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

# 2. Build and Tag Docker Image
echo "[2/5] Building Docker container image..."
docker build -t "${IMAGE_URI}" -t "${ECR_REGISTRY}/${ECR_REPO_NAME}:latest" .

# 3. Push to ECR
echo "[3/5] Pushing image to ECR..."
docker push "${IMAGE_URI}"
docker push "${ECR_REGISTRY}/${ECR_REPO_NAME}:latest"

# 4. Apply Kubernetes Manifests
echo "[4/5] Applying Kubernetes manifests..."
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/autoscaling.yaml
kubectl apply -f k8s/pdb.yaml
kubectl apply -f k8s/networkpolicy.yaml

# If secret does not exist, warn user
if ! kubectl get secret cems-secret -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
    echo "WARNING: Secret 'cems-secret' not found in namespace '${K8S_NAMESPACE}'!"
    echo "Creating secret from k8s/secret-template.yaml. UPDATE WITH REAL SECRETS!"
    kubectl apply -f k8s/secret-template.yaml
fi

# Set image to newly pushed commit tag
kubectl set image deployment/cems-deployment cems-app="${IMAGE_URI}" -n "${K8S_NAMESPACE}"

# 5. Wait for rollout
echo "[5/5] Waiting for zero-downtime rolling update..."
kubectl rollout status deployment/cems-deployment -n "${K8S_NAMESPACE}" --timeout=180s

echo "=========================================================="
echo " Deployment Complete!"
echo " Ingress Hostname:"
kubectl get ingress cems-ingress -n "${K8S_NAMESPACE}" -o wide
echo "=========================================================="
