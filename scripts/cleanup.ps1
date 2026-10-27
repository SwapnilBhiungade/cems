<#
.SYNOPSIS
    Automated AWS Cloud Resource Teardown for CEMS (PowerShell)
#>

[CmdletBinding()]
param (
    [string]$AwsRegion = "ap-south-1",
    [string]$ClusterName = "cems-cluster",
    [string]$EcrRepoName = "cems-app",
    [string]$K8sNamespace = "cems"
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Red
Write-Host "          CEMS AWS CLOUD CLEANUP AND TEARDOWN" -ForegroundColor Red
Write-Host "==========================================================" -ForegroundColor Red
Write-Host "WARNING: This will permanently delete:" -ForegroundColor Yellow
Write-Host " 1. Kubernetes Ingress and AWS ALB" -ForegroundColor Yellow
Write-Host " 2. EKS Cluster '$ClusterName' and all EC2 nodes" -ForegroundColor Yellow
Write-Host " 3. ECR Repository '$EcrRepoName' and images" -ForegroundColor Yellow

$confirm = Read-Host "Type 'yes' to proceed with deletion"
if ($confirm -ne "yes") {
    Write-Host "Cleanup aborted." -ForegroundColor Green
    exit 0
}

Write-Host "[1/4] Deleting Kubernetes Ingress (deprovisioning ALB)..." -ForegroundColor Yellow
kubectl delete ingress cems-ingress -n $K8sNamespace --ignore-not-found=true
Start-Sleep -Seconds 30

Write-Host "[2/4] Deleting CEMS namespace..." -ForegroundColor Yellow
kubectl delete namespace $K8sNamespace --ignore-not-found=true

Write-Host "[3/4] Deleting EKS Cluster (takes ~10-15 minutes)..." -ForegroundColor Yellow
eksctl delete cluster --name $ClusterName --region $AwsRegion

Write-Host "[4/4] Deleting Amazon ECR repository..." -ForegroundColor Yellow
aws ecr delete-repository --repository-name $EcrRepoName --region $AwsRegion --force

Write-Host "Teardown complete! Verify your AWS billing and EC2 dashboard." -ForegroundColor Green
