<#
.SYNOPSIS
    Automated AWS Cloud Infrastructure Provisioning for CEMS (PowerShell)
.DESCRIPTION
    Creates ECR Repository, EKS Cluster, Node Group, and installs Metrics Server.
#>

[CmdletBinding()]
param (
    [string]$AwsRegion = "ap-south-1",
    [string]$ClusterName = "cems-cluster",
    [string]$EcrRepoName = "cems-app",
    [string]$K8sVersion = "1.30",
    [string]$NodeType = "t3.medium",
    [int]$NodeCount = 2,
    [int]$MinNodes = 2,
    [int]$MaxNodes = 4
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting AWS Infrastructure Provisioning for CEMS" -ForegroundColor Cyan
Write-Host " Region:    $AwsRegion" -ForegroundColor Cyan
Write-Host " Cluster:   $ClusterName" -ForegroundColor Cyan
Write-Host " Node Type: $NodeType" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify AWS Identity
Write-Host "[1/5] Checking AWS credentials..." -ForegroundColor Yellow
$callerId = aws sts get-caller-identity --output json | ConvertFrom-Json
$awsAccountId = $callerId.Account
Write-Host "Authenticated as AWS Account: $awsAccountId" -ForegroundColor Green

# 2. Create ECR Repository
Write-Host "[2/5] Creating Amazon ECR repository '$EcrRepoName'..." -ForegroundColor Yellow
$repoCheck = aws ecr describe-repositories --repository-names $EcrRepoName --region $AwsRegion 2>$null
if (-not $repoCheck) {
    aws ecr create-repository --repository-name $EcrRepoName --region $AwsRegion --image-scanning-configuration scanOnPush=true
    Write-Host "ECR repository created." -ForegroundColor Green
} else {
    Write-Host "ECR repository already exists." -ForegroundColor Gray
}

# 3. Create EKS Cluster via eksctl
Write-Host "[3/5] Provisioning EKS Cluster (this takes ~15 minutes)..." -ForegroundColor Yellow
eksctl create cluster `
    --name $ClusterName `
    --region $AwsRegion `
    --version $K8sVersion `
    --nodegroup-name "cems-nodes" `
    --node-type $NodeType `
    --nodes $NodeCount `
    --nodes-min $MinNodes `
    --nodes-max $MaxNodes `
    --managed `
    --with-oidc

# 4. Update kubeconfig
Write-Host "[4/5] Updating kubeconfig context..." -ForegroundColor Yellow
aws eks update-kubeconfig --name $ClusterName --region $AwsRegion
kubectl get nodes

# 5. Deploy Metrics Server
Write-Host "[5/5] Deploying Kubernetes Metrics Server..." -ForegroundColor Yellow
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " AWS Setup Finished Successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
