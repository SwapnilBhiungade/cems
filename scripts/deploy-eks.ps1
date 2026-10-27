<#
.SYNOPSIS
    Automated EKS Deployment Script for CEMS (PowerShell)
#>

[CmdletBinding()]
param (
    [string]$AwsRegion = "ap-south-1",
    [string]$ClusterName = "cems-cluster",
    [string]$EcrRepoName = "cems-app",
    [string]$K8sNamespace = "cems"
)

$ErrorActionPreference = "Stop"

$callerId = aws sts get-caller-identity --output json | ConvertFrom-Json
$awsAccountId = $callerId.Account
$ecrRegistry = "$awsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"
$gitTag = git rev-parse --short HEAD 2>$null
if (-not $gitTag) { $gitTag = "v1.0.0" }
$fullImage = "$ecrRegistry/${EcrRepoName}:$gitTag"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Deploying CEMS to Amazon EKS" -ForegroundColor Cyan
Write-Host " Image:   $fullImage" -ForegroundColor Cyan
Write-Host " Cluster: $ClusterName" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. ECR Login
Write-Host "[1/5] Authenticating with Amazon ECR..." -ForegroundColor Yellow
aws ecr get-login-password --region $AwsRegion | docker login --username AWS --password-stdin $ecrRegistry

# 2. Build Image
Write-Host "[2/5] Building Docker image..." -ForegroundColor Yellow
docker build -t $fullImage -t "$ecrRegistry/${EcrRepoName}:latest" .

# 3. Push Image
Write-Host "[3/5] Pushing image to ECR..." -ForegroundColor Yellow
docker push $fullImage
docker push "$ecrRegistry/${EcrRepoName}:latest"

# 4. Apply Manifests
Write-Host "[4/5] Updating kubeconfig and applying manifests..." -ForegroundColor Yellow
aws eks update-kubeconfig --name $ClusterName --region $AwsRegion
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/autoscaling.yaml
kubectl apply -f k8s/pdb.yaml
kubectl apply -f k8s/networkpolicy.yaml

# Set image
kubectl set image deployment/cems-deployment cems-app=$fullImage -n $K8sNamespace

# 5. Wait for rollout
Write-Host "[5/5] Waiting for deployment rollout..." -ForegroundColor Yellow
kubectl rollout status deployment/cems-deployment -n $K8sNamespace --timeout=180s

Write-Host "Deployment completed successfully!" -ForegroundColor Green
kubectl get ingress cems-ingress -n $K8sNamespace
