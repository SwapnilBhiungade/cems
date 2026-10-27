# Campus Event Management System (CEMS)
## End-to-End DevOps Deployment Guide on AWS Using Docker, Kubernetes (EKS), Jenkins, Prometheus, and Grafana

---

## 1. Project Overview and Objectives

The Campus Event Management System (CEMS) is a full-featured web application designed for collegiate institutions to manage events, student registrations, entry passes, gallery media, student feedback, and administrative communications.

### Core Objectives:
1. **Containerization**: Package the Python Flask application and its dependencies into a hardened, non-root, multi-stage Docker container.
2. **Local Reproducibility**: Provide a zero-friction local development environment using Docker Compose with persistent MySQL storage.
3. **Cloud-Native Kubernetes Deployment**: Deploy the containerized application onto Amazon Elastic Kubernetes Service (EKS) across multiple Availability Zones in `ap-south-1` (Mumbai).
4. **Automated CI/CD Pipeline**: Build a declarative Jenkins pipeline automating git checkout, linting, security scanning, unit testing, Docker image building, Amazon ECR publishing, zero-downtime rolling deployment to EKS, and post-deployment smoke tests.
5. **Elastic Scalability & Self-Healing**: Implement Horizontal Pod Autoscaler (HPA) targeting CPU/memory utilization, readiness/liveness health probes, and PodDisruptionBudgets.
6. **Full-Stack Observability**: Deploy Prometheus and Grafana via Helm to capture real-time application throughput, latency, pod restarts, and Kubernetes cluster resource usage.
7. **Security & Production Readiness**: Run containers as non-root users, drop Linux privileges, safeguard database credentials with Kubernetes Secrets, and secure session state.

---

## 2. Existing Application Architecture

### Inspected Codebase Summary:
- **Backend Framework**: Python 3.11 with Flask 2.3.3 and Werkzeug 2.3.7.
- **Frontend Architecture**: Server-Side Rendering (SSR) using Jinja2 templates (`templates/`) with static CSS and JavaScript (`static/`).
- **Database Connectivity**: Managed via custom `DBWrapper` in `app.py`, creating request-scoped MySQL connections from `config.py` environment variables.
- **Authentication & Security**: Bcrypt password hashing, Flask session cookies with HTTPOnly/SameSite flags, and CSRF protection via Flask-WTF `CSRFProtect`.
- **Pass Generation**: Stateless, in-memory PDF streaming utilizing ReportLab (`reportlab.platypus.SimpleDocTemplate` writing to `io.BytesIO()`).
- **Media Uploads**: Cloudinary integration for cloud-based gallery image hosting.

### Evaluated Container Architecture:
- *Separating Frontend into Single Page Application (SPA)* was rejected as it would require rewriting 2,500 lines of Flask views into JSON REST APIs, breaking existing CSRF tokens and session authentication without functional benefit.
- *Selected Architecture*: Unified, production-grade Gunicorn WSGI container (`wsgi:app`) deployed behind the AWS Application Load Balancer (ALB).

---

## 3. Final Architecture and Component Interaction

```mermaid
graph LR
    User([End User / Student]) -->|HTTPS:443 / HTTP:80| ALB[AWS Application Load Balancer]
    ALB -->|Target Type: IP| Pod1[CEMS Pod 1 - Gunicorn]
    ALB -->|Target Type: IP| Pod2[CEMS Pod 2 - Gunicorn]
    Pod1 -->|Port 3306| RDS[(Amazon RDS MySQL 8.0)]
    Pod2 -->|Port 3306| RDS
    Pod1 -->|Media Uploads| Cloudinary[(Cloudinary Media CDN)]
    Prometheus[Prometheus Server] -->|Scrapes :5000/metrics| Pod1
    Prometheus -->|Scrapes :5000/metrics| Pod2
    Grafana[Grafana Dashboard] -->|Visualizes Metrics| Prometheus
```

1. **Client Request**: User connects to the public DNS hostname of the AWS Application Load Balancer (ALB).
2. **Traffic Routing**: The AWS Load Balancer Controller routes traffic directly to private pod IPs using AWS VPC CNI.
3. **Execution**: Gunicorn handles concurrent requests across threads, rendering Jinja2 templates.
4. **Data Persistence**: Pods query the Amazon RDS MySQL database in private subnets.
5. **Assets**: Gallery photos are fetched from and stored to Cloudinary CDN; static CSS/JS are served directly by Gunicorn.
6. **Monitoring**: Prometheus scrapes `/metrics` on port 5000 every 15 seconds.

---

## 4. Newly Created & Modified Files Directory

| File Path | Description & Purpose |
|---|---|
| `Dockerfile` | Multi-stage, hardened, non-root (`cemsuser`) production container specification. |
| `compose.yaml` | Multi-container Docker Compose file orchestrating CEMS web and MySQL 8.0 with volume persistence. |
| `.dockerignore` | Build context exclusions to prevent credential leakage and minimize image size. |
| `.env.example` | Template documenting environment variables for both Local (Mode A) and AWS RDS (Mode B). |
| `gunicorn.conf.py` | Production WSGI configuration with worker recycling, logging, and graceful timeouts. |
| `Jenkinsfile` | Declarative 12-stage CI/CD pipeline definition for automated builds, testing, scanning, and EKS rollouts. |
| `app.py` *(Modified)* | Added `/health` and `/healthz` endpoints and Prometheus metrics instrumentation (`/metrics`). |
| `init_db.py` *(Modified)* | Added connection retry loop to handle database startup delays gracefully. |
| `requirements.txt` *(Modified)* | Added `prometheus-flask-exporter>=0.23.0` dependency. |
| `requirements-dev.txt` | Development dependencies: `pytest`, `flake8`, `bandit`, `requests`, `python-docx`. |
| `bandit.yaml` | Static Application Security Testing (SAST) rule definitions. |
| `.flake8` | Python code style linter rules and exclusions. |
| `tests/conftest.py` | Pytest fixtures and test environment variables. |
| `tests/test_app.py` | Automated unit and integration tests (health, auth, metrics, error handling). |
| `tests/test_smoke.py` | Post-deployment smoke test script validating live URLs. |
| `k8s/namespace.yaml` | Kubernetes `cems` namespace manifest. |
| `k8s/configmap.yaml` | Non-sensitive runtime application configuration. |
| `k8s/secret-template.yaml` | Secret template for database password, Flask secret key, and Cloudinary keys. |
| `k8s/deployment.yaml` | 2-replica Deployment with rolling updates, resource limits, security context, and health probes. |
| `k8s/service.yaml` | ClusterIP Service routing internal port 80 to container port 5000. |
| `k8s/ingress.yaml` | AWS ALB Ingress with target-type IP and health check configurations. |
| `k8s/autoscaling.yaml` | HorizontalPodAutoscaler (HPA) scaling between 2 and 8 pods at 70% CPU / 80% Memory. |
| `k8s/pdb.yaml` | PodDisruptionBudget ensuring a minimum of 1 healthy pod during node updates. |
| `k8s/networkpolicy.yaml` | Network isolation policy restricting incoming traffic. |
| `k8s/database/*` | In-cluster MySQL StatefulSet, PVC, Service, and Secret manifests for college evaluation mode. |
| `monitoring/helm-values.yaml` | Custom values for `kube-prometheus-stack` Helm chart. |
| `monitoring/service-monitor.yaml` | Prometheus ServiceMonitor targeting CEMS pods. |
| `monitoring/alerts/cems-alerts.yaml` | Prometheus alerting rules for downtime, 5xx errors, restart spikes, and CPU/RAM pressure. |
| `monitoring/dashboards/cems-dashboard.json`| Pre-built Grafana dashboard JSON with 8 performance panels. |
| `scripts/init_mysql.sql` | SQL schema and admin account script for container initialization. |
| `scripts/setup-jenkins.sh` | Bash script installing Jenkins, Docker, AWS CLI, kubectl, and Trivy on Ubuntu EC2. |
| `scripts/aws-setup.sh` / `.ps1` | Automated AWS infrastructure setup (ECR, EKS, Node Group, Metrics Server). |
| `scripts/deploy-eks.sh` / `.ps1` | Automated image build, ECR push, and EKS manifest deployment. |
| `scripts/cleanup.sh` / `.ps1` | Safe automated AWS teardown script to terminate billing. |

---

## 5. Prerequisites and Software Installation

Before starting, install the following tools on your local development machine:

### Required Local Tools:
1. **Python 3.11+**: Download from [python.org](https://www.python.org/downloads/). Ensure "Add Python to PATH" is checked.
2. **Git**: Download from [git-scm.com](https://git-scm.com/).
3. **Docker Desktop**: Download from [docker.com](https://www.docker.com/products/docker-desktop/). Enable WSL 2 backend on Windows.
4. **kubectl**: Kubernetes CLI tool (`kubectl version --client`).
5. **AWS CLI v2**: Download from [aws.amazon.com/cli](https://aws.amazon.com/cli/). Verify with `aws --version`.
6. **eksctl**: EKS cluster manager from [eksctl.io](https://eksctl.io/).

---

## 6. Local Docker Compose Setup

- **Objective**: Run the complete CEMS stack locally using Docker containers.
- **Where to Run**: Windows PowerShell or Linux/macOS Terminal.
- **Incurs AWS Charges?**: ❌ No.

### Step 1: Start Docker Desktop
Launch Docker Desktop and ensure the whale icon in the taskbar shows "Engine running".

### Step 2: Build and Start Containers
```bash
# In the project root directory:
docker compose up -d --build
```

### Step 3: Verify Container Health
```bash
docker compose ps
```
*Expected Output:*
```text
NAME         IMAGE            COMMAND                  SERVICE   CREATED          STATUS                    PORTS
cems-mysql   mysql:8.0        "docker-entrypoint.s…"   mysql     20 seconds ago   Up 19 seconds (healthy)   0.0.0.0:3306->3306/tcp
cems-web     cems-app:local   "gunicorn --config g…"   app       20 seconds ago   Up 5 seconds (healthy)    0.0.0.0:5000->5000/tcp
```

### Step 4: Access Local Application
Open your browser to:
- **Application URL**: `http://localhost:5000`
- **Default Admin Account**: `admin@campus.edu` / `admin123`

---

## 7. Database Initialization and Migration

- **Objective**: Verify that MySQL schema and the default admin user exist.
- **Where to Run**: Local Terminal or Container Shell.
- **Incurs AWS Charges?**: ❌ No.

### Local Container Strategy:
The file `scripts/init_mysql.sql` is mounted to `/docker-entrypoint-initdb.d/01_init.sql`. MySQL executes it automatically on first startup.

### Manual / Existing DB Strategy:
If you need to initialize an external database (e.g. AWS RDS):
```bash
# Set environment variables for the target DB
python init_db.py
```
*Expected Output:*
```text
Connecting to database (attempt 1/15)...
Successfully connected to MySQL database.
Database initialized successfully!
Default admin account: admin@campus.edu / admin123
```

---

## 8. Local Application Testing & Quality Checks

- **Objective**: Run unit tests, linting, and security scans locally before pushing code.
- **Where to Run**: Windows PowerShell or Linux Terminal.
- **Incurs AWS Charges?**: ❌ No.

### Step 1: Run Pytest Unit Tests
```bash
python -m pytest tests/test_app.py -v
```
*Expected Output:* `9 passed in 0.24s`

### Step 2: Run Flake8 Code Style Linter
```bash
flake8 tests/ gunicorn.conf.py
```
*Expected Output:* Clean exit (exit code 0, no output).

### Step 3: Run Bandit SAST Security Scan
```bash
bandit -c bandit.yaml -r tests/ gunicorn.conf.py
```
*Expected Output:* `No issues identified.`

---

## 9. AWS Account and IAM Prerequisites

- **Objective**: Configure AWS credentials with appropriate administrative permissions.
- **Where to Run**: Local Terminal / AWS CLI.
- **Incurs AWS Charges?**: ❌ No.

### Step 1: Configure AWS CLI Credentials
Run:
```bash
aws configure
```
Provide your details:
- **AWS Access Key ID**: Your access key
- **AWS Secret Access Key**: Your secret key
- **Default region name**: `ap-south-1`
- **Default output format**: `json`

### Step 2: Verify Identity
```bash
aws sts get-caller-identity
```

---

## 10. ECR Repository Creation and Image Publishing

- **Objective**: Create a container repository in Amazon ECR and push the Docker image.
- **Where to Run**: Local Terminal.
- **Incurs AWS Charges?**: ✅ Minimal (< $0.05 / month for image storage).

### Commands (Linux/macOS):
```bash
export AWS_REGION="ap-south-1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
export IMAGE_TAG=$(git rev-parse --short HEAD)

# 1. Create ECR repository
aws ecr create-repository --repository-name cems-app --region ${AWS_REGION} --image-scanning-configuration scanOnPush=true

# 2. Authenticate Docker with ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# 3. Build and Tag image
docker build -t ${ECR_REGISTRY}/cems-app:${IMAGE_TAG} -t ${ECR_REGISTRY}/cems-app:latest .

# 4. Push image
docker push ${ECR_REGISTRY}/cems-app:${IMAGE_TAG}
docker push ${ECR_REGISTRY}/cems-app:latest
```

---

## 11. EKS Cluster and Node Group Creation

- **Objective**: Provision an Amazon EKS cluster with 2 managed worker nodes.
- **Where to Run**: Local Terminal.
- **Incurs AWS Charges?**: ✅ Yes (~$0.18 / hour while running).

### Command:
```bash
eksctl create cluster \
  --name cems-cluster \
  --region ap-south-1 \
  --version 1.30 \
  --nodegroup-name cems-nodes \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 4 \
  --managed \
  --with-oidc
```
*Note*: This process takes 12–18 minutes.

### Verification:
```bash
kubectl get nodes
```
*Expected Output:* 2 nodes in `Ready` status.

---

## 12. Database Setup and Secure Connectivity

### Production Choice: Amazon RDS for MySQL
1. Navigate to **AWS Console** → **RDS** → **Create Database**.
2. Select **Standard create** → **MySQL 8.0**.
3. Template: **Free tier** (or Dev/Test).
4. DB Instance identifier: `cems-mysql-db`.
5. Master username: `cems_admin`. Master password: Choose a strong password.
6. DB instance class: `db.t4g.micro` or `db.t3.micro`.
7. Connectivity: Select the VPC created by `eksctl` (`eksctl-cems-cluster-cluster/VPC`).
8. Public access: **No** (keeps database private and secure).
9. Security group: Allow inbound port 3306 from the EKS Node Group security group.
10. Initial database name: `campus_events`.

---

## 13. Kubernetes Deployment

- **Objective**: Deploy CEMS ConfigMap, Secrets, Services, and Deployments to EKS.
- **Where to Run**: Local Terminal or Jenkins.
- **Incurs AWS Charges?**: Covered under EC2 node compute.

### Step 1: Create Namespace
```bash
kubectl apply -f k8s/namespace.yaml
```

### Step 2: Configure Secrets
```bash
kubectl create secret generic cems-secret -n cems \
  --from-literal=SECRET_KEY="replace-with-64-character-random-hex-key" \
  --from-literal=DB_PASSWORD="your-actual-rds-password" \
  --from-literal=CLOUDINARY_URL="cloudinary://api_key:api_secret@cloud_name"
```

### Step 3: Update ConfigMap
Edit `k8s/configmap.yaml` with your RDS endpoint:
```yaml
data:
  DB_HOST: "cems-mysql-db.xxxxxxxxx.ap-south-1.rds.amazonaws.com"
```
Apply ConfigMap:
```bash
kubectl apply -f k8s/configmap.yaml
```

### Step 4: Deploy Workloads
```bash
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/pdb.yaml
kubectl apply -f k8s/networkpolicy.yaml
kubectl apply -f k8s/deployment.yaml

# Set the image to your ECR image tag:
kubectl set image deployment/cems-deployment cems-app=<AWS_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/cems-app:<IMAGE_TAG> -n cems
```

### Step 5: Verify Rollout
```bash
kubectl rollout status deployment/cems-deployment -n cems
kubectl get pods -n cems
```

---

## 14. Public Website Access & AWS Ingress Configuration

- **Objective**: Expose CEMS through an AWS Application Load Balancer (ALB).
- **Where to Run**: Local Terminal.

### Step 1: Deploy AWS Load Balancer Controller
Follow the commands documented in `scripts/aws-setup.sh` to install the AWS Load Balancer Controller via Helm.

### Step 2: Apply Ingress
```bash
kubectl apply -f k8s/ingress.yaml
```

### Step 3: Retrieve Public URL
```bash
kubectl get ingress cems-ingress -n cems
```
*Expected Output:*
```text
NAME           CLASS   HOSTS   ADDRESS                                                        PORTS   AGE
cems-ingress   alb     *       k8s-cems-cemsingr-xxxxxxxxxx.ap-south-1.elb.amazonaws.com     80      2m
```
Open `http://<ADDRESS>` in your browser to access CEMS live on AWS Cloud!

---

## 15. Jenkins Installation and Configuration

- **Objective**: Provision a dedicated CI/CD server on AWS EC2.
- **Where to Run**: Ubuntu EC2 Instance Terminal.

1. Launch an EC2 instance: **Ubuntu 22.04 LTS**, instance type **t3.medium**, with 30GB disk.
2. In Security Group, allow inbound **TCP 8080** (restricted to your IP) and **SSH 22**.
3. SSH into the instance and run the automated setup script:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/<YOUR-GITHUB-REPO>/main/scripts/setup-jenkins.sh -o setup-jenkins.sh
   chmod +x setup-jenkins.sh
   ./setup-jenkins.sh
   ```
4. Access Jenkins at `http://<EC2-IP>:8080`.
5. Enter the initial admin password from `/var/lib/jenkins/secrets/initialAdminPassword`.
6. Install suggested plugins.

---

## 16. GitHub Webhook and CI/CD Setup

1. In Jenkins: **New Item** → Name: `CEMS-Pipeline` → Select **Pipeline** → Click **OK**.
2. Under **Build Triggers**, check **GitHub hook trigger for GITScm polling**.
3. Under **Pipeline**:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/<YOUR-USERNAME>/CEMS.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
4. In GitHub Repository: **Settings** → **Webhooks** → **Add webhook**:
   - Payload URL: `http://<JENKINS-IP>:8080/github-webhook/`
   - Content type: `application/json`
   - Which events? **Just the push event**.

---

## 17. End-to-End Commit-to-Deployment Workflow

1. Developer makes a code modification on local machine (e.g. updating an event description).
2. Commit and push:
   ```bash
   git add .
   git commit -m "feat: enhance event registration workflow"
   git push origin main
   ```
3. GitHub triggers the webhook. Jenkins immediately executes the 12-stage pipeline:
   - Checkout SCM → Install Dev Dependencies → Flake8 Linting → Bandit Security → Pytest Tests → Docker Build → Trivy Scan → Push to ECR → Deploy to EKS → Rollout Status → Smoke Tests.
4. EKS updates pods zero-downtime using rolling update (`maxSurge: 1`, `maxUnavailable: 0`).

---

## 18. Autoscaling Configuration and Testing (HPA)

### Install Metrics Server:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Apply HPA:
```bash
kubectl apply -f k8s/autoscaling.yaml
```

### Test Elastic Scale-Out:
Run a synthetic load generator in a separate terminal:
```bash
kubectl run load-gen --rm -it --image=busybox -n cems -- /bin/sh -c \
  "while true; do wget -q -O- http://cems-service/health; done"
```
Monitor the autoscaling behavior:
```bash
kubectl get hpa -n cems -w
```
Watch the replica count expand from 2 up to 4+ as CPU exceeds 70%!

---

## 19. Self-Healing Demonstration

Demonstrate Kubernetes self-healing to your examiner:
```bash
# 1. View running pods
kubectl get pods -n cems

# 2. Delete one pod manually
kubectl delete pod <POD-NAME> -n cems

# 3. Observe instant reconciliation
kubectl get pods -n cems
```
The deleted pod is instantly terminated and replaced with a fresh pod in seconds.

---

## 20. Prometheus and Grafana Monitoring Installation

```bash
# 1. Add Prometheus Community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Install Monitoring Stack
helm install cems-monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f monitoring/helm-values.yaml

# 3. Apply ServiceMonitor and Custom Alert Rules
kubectl apply -f monitoring/service-monitor.yaml
kubectl apply -f monitoring/alerts/cems-alerts.yaml
```

---

## 21. Dashboard Configuration and Validation

### Access Grafana:
```bash
kubectl port-forward svc/cems-monitoring-grafana -n monitoring 3000:80
```
1. Open `http://localhost:3000` in browser.
2. Login: User `admin`, Password `AdminCemsSecurePass2026!`.
3. Navigate to **Dashboards** → **Import**.
4. Upload `monitoring/dashboards/cems-dashboard.json`.
5. View real-time graphs of HTTP request rate, P95 latency, CPU/RAM, and replica health!

---

## 22. Application & Deployment Troubleshooting

Refer to `docs/TROUBLESHOOTING.md` for specific issue matrices:
- **CrashLoopBackOff**: Missing secrets or database unreachable.
- **502 Bad Gateway**: Check pod readiness probes on `/health`.
- **ImagePullBackOff**: Node IAM role missing ECR read permissions.

---

## 23. Rollback Procedures

If an updated deployment fails smoke tests or contains bugs:
```bash
# Check rollout history
kubectl rollout history deployment/cems-deployment -n cems

# Roll back to the immediately preceding revision
kubectl rollout undo deployment/cems-deployment -n cems

# Verify rollback
kubectl rollout status deployment/cems-deployment -n cems
```

---

## 24. Security Checklist

- [x] Application container runs as non-root (`cemsuser`, UID 10001).
- [x] Linux capabilities dropped (`drop: ["ALL"]`).
- [x] No sensitive `.env` files or certificates baked into Docker image.
- [x] MySQL database not publicly accessible (private subnets only).
- [x] CSRF protection enabled on all user form submissions.
- [x] Password hashing using Bcrypt with salt.
- [x] Ingress terminates HTTPS (optional with ACM certificate).

---

## 25. AWS Cost Considerations

Refer to `docs/COST_AND_CLEANUP.md`.
- Average hourly cost: **~$0.33 – $0.35 / hour**.
- Running continuously for 30 days costs ~$200.
- **Always clean up immediately after your presentation.**

---

## 26. Complete Cleanup Procedure

To terminate all billable resources:
```bash
# Automated cleanup:
./scripts/cleanup.sh

# Or on Windows PowerShell:
.\scripts\cleanup.ps1
```

---

## 27. Expected Results and Verification Checklist

| Check | Command / Verification | Pass Criteria |
|---|---|---|
| Local Docker | `docker compose ps` | Both containers report `(healthy)` |
| Unit Tests | `pytest tests/test_app.py` | 9 passed in < 1s |
| Linting | `flake8 tests/` | 0 errors |
| Security Scan | `bandit -c bandit.yaml ...` | 0 high/medium issues |
| EKS Cluster | `kubectl get nodes` | 2 nodes `Ready` |
| Ingress / ALB | `kubectl get ingress -n cems` | Public ALB address assigned |
| Self-Healing | `kubectl delete pod ...` | Pod resurrected in < 5s |
| HPA Scale-Out | `kubectl get hpa -n cems` | Pods scale up under load |
| Grafana | `http://localhost:3000` | CEMS dashboard displays live metrics |

---

## 28. Limitations and Future Improvements

1. **Database Multi-Region Replication**: Future iterations can employ AWS Aurora Global Database for multi-region active-active deployments.
2. **GitOps with ArgoCD**: Upgrade from Jenkins push-based deployments to declarative pull-based GitOps with ArgoCD.
3. **Canary Deployments with Flagger**: Automate progressive canary deployments using Flagger and AWS App Mesh.
4. **CloudFront CDN Caching**: Place AWS CloudFront in front of the Application Load Balancer for global edge caching of static assets.
