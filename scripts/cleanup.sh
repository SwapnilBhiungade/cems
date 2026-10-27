#!/usr/bin/env bash
# ==============================================================================
# Script: cleanup.sh
# Purpose: Safely teardown all CEMS AWS cloud resources to terminate billing.
# WARNING: DESTRUCTIVE ACTION. Removes Ingress (ALB), EKS Cluster, and ECR.
# ==============================================================================

set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-cems-cluster}"
ECR_REPO_NAME="${ECR_REPO_NAME:-cems-app}"
K8S_NAMESPACE="${K8S_NAMESPACE:-cems}"

echo "=========================================================="
echo "          CEMS AWS CLOUD CLEANUP AND TEARDOWN"
echo "=========================================================="
echo "WARNING: This script will permanently delete:"
echo " 1. Kubernetes Ingress & AWS Application Load Balancer"
echo " 2. EKS Cluster '${CLUSTER_NAME}' and all worker nodes"
echo " 3. ECR Repository '${ECR_REPO_NAME}' and all images"
echo "Region: ${AWS_REGION}"
echo "=========================================================="
read -p "Are you sure you want to proceed? (Type 'yes' to confirm): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo "[1/4] Deleting Kubernetes Ingress to trigger AWS ALB deletion..."
kubectl delete ingress cems-ingress -n "${K8S_NAMESPACE}" --ignore-not-found=true
echo "Waiting 30 seconds for ALB deprovisioning..."
sleep 30

echo "[2/4] Deleting CEMS Kubernetes Namespace..."
kubectl delete namespace "${K8S_NAMESPACE}" --ignore-not-found=true

echo "[3/4] Deleting Amazon EKS Cluster and Node Groups via eksctl..."
eksctl delete cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" || true

echo "[4/4] Deleting Amazon ECR Repository..."
aws ecr delete-repository --repository-name "${ECR_REPO_NAME}" --region "${AWS_REGION}" --force || true

echo "=========================================================="
echo " Teardown completed. Check AWS Console to verify that"
echo " no active EC2 instances, ALBs, or NAT Gateways remain."
echo "=========================================================="
