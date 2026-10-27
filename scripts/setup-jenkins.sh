#!/usr/bin/env bash
# ==============================================================================
# Script: setup-jenkins.sh
# Purpose: Automated installation and configuration of Jenkins, Docker,
#          AWS CLI v2, kubectl, and Trivy on Ubuntu 22.04 / 24.04 LTS (AWS EC2).
# Requirements: Run as root or with sudo on an EC2 t3.medium or larger instance.
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo " Starting Jenkins CI/CD Server Installation for CEMS"
echo "=========================================================="

# 1. Update OS packages
echo "[1/7] Updating system packages..."
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    python3 \
    python3-pip \
    python3-venv \
    git \
    unzip

# 2. Install OpenJDK 17 (Required by Jenkins)
echo "[2/7] Installing Java OpenJDK 17..."
sudo apt-get install -y openjdk-17-jdk
java -version

# 3. Install Jenkins LTS
echo "[3/7] Installing Jenkins LTS..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /etc/apt/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y jenkins

# 4. Install Docker Engine
echo "[4/7] Installing Docker Engine..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add jenkins and ubuntu users to docker group
sudo usermod -aG docker jenkins
sudo usermod -aG docker "${USER:-ubuntu}"
sudo chmod 666 /var/run/docker.sock || true

# 5. Install AWS CLI v2
echo "[5/7] Installing AWS CLI v2..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip
aws --version

# 6. Install kubectl
echo "[6/7] Installing kubectl..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
kubectl version --client

# 7. Install Trivy Vulnerability Scanner
echo "[7/7] Installing Trivy Scanner..."
sudo apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update -y
sudo apt-get install -y trivy
trivy --version

# Restart Jenkins to pick up group memberships
echo "Restarting Jenkins service..."
sudo systemctl enable jenkins
sudo systemctl restart jenkins
sudo systemctl enable docker
sudo systemctl restart docker

echo "=========================================================="
echo " Jenkins CI/CD Server Installation Complete!"
echo " Access Jenkins at: http://<EC2-PUBLIC-IP>:8080"
echo " Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo "=========================================================="
