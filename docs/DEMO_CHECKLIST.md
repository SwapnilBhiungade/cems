# College Project Evaluator Demonstration Checklist

This document is your step-by-step presentation script for demonstrating the **Campus Event Management System (CEMS) End-to-End DevOps & AWS Deployment** to your college evaluators and external examiners.

---

## Demonstration Overview Table

| Demo # | Core Concept Proved | Key Command / Action | Expected Outcome |
|---|---|---|---|
| **Demo 1** | Local Containerization & DB Persistence | `docker compose up -d` | App running on `localhost:5000`, MySQL on `3306`, volume persists data |
| **Demo 2** | Code Quality & SAST Security Scanning | `flake8 tests/` & `bandit -c bandit.yaml ...` | 0 linting errors, 0 high/medium security vulnerabilities |
| **Demo 3** | Automated Unit & Integration Testing | `pytest tests/test_app.py -v` | All 9 tests passing (health, auth, metrics, rendering) |
| **Demo 4** | Kubernetes Cluster & ALB Ingress | `kubectl get nodes,pods,svc,ingress -n cems` | 2 healthy pods, ClusterIP service, active AWS Ingress URL |
| **Demo 5** | Public Cloud Application Validation | Open public AWS ALB DNS URL in browser | Full interactive website working on AWS |
| **Demo 6** | Pod-Level Self-Healing & Reconciliation | `kubectl delete pod <pod-name> -n cems` | Deleted pod replaced immediately in < 5 seconds |
| **Demo 7** | Horizontal Pod Autoscaler (HPA) Elasticity | Run ApacheBench or Hey load test generator | HPA scales pods from 2 to 4+ replicas automatically |
| **Demo 8** | Jenkins CI/CD Automated Commit-to-Deploy | Push small Git commit to GitHub | Pipeline triggers, builds, scans, pushes to ECR, and deploys to EKS |
| **Demo 9** | Prometheus Metrics & Grafana Observability | Open Grafana at `localhost:3000` or port-forward | Live dashboard showing req/sec, P95 latency, CPU/memory |

---

## Detailed Demonstration Runbook

### Demo 1: Local Development & Containerization
- **Concept Proved**: 12-Factor App methodology, multi-container orchestration, and database volume persistence.
- **Commands**:
  ```bash
  # Start local multi-container stack
  docker compose up -d --build

  # Verify container status and health
  docker compose ps
  ```
- **Screenshot 1 to Capture**: Output of `docker compose ps` showing `cems-web` and `cems-mysql` with `(healthy)` status.
- **Verification**: Open `http://localhost:5000` in browser. Log in using `admin@campus.edu` / `admin123`.

---

### Demo 2: Code Quality & Security Auditing
- **Concept Proved**: Shift-Left Security and static analysis in modern DevOps.
- **Commands**:
  ```bash
  # Run PEP 8 linter
  flake8 tests/ gunicorn.conf.py

  # Run Bandit static security scan
  bandit -c bandit.yaml -r tests/ gunicorn.conf.py
  ```
- **Screenshot 2 to Capture**: Terminal showing `No issues identified` from Bandit and 0 errors from flake8.

---

### Demo 3: Automated Unit Testing
- **Concept Proved**: Automated test gate preventing broken builds from reaching container images.
- **Command**:
  ```bash
  python -m pytest tests/test_app.py -v
  ```
- **Screenshot 3 to Capture**: Pytest summary displaying `9 passed in 0.24s`.

---

### Demo 4: Kubernetes Resources on AWS EKS
- **Concept Proved**: Cloud-native orchestration, pod distribution, and AWS Load Balancer Controller integration.
- **Command**:
  ```bash
  kubectl get all,ingress,hpa -n cems -o wide
  ```
- **Screenshot 4 to Capture**: Output showing `cems-deployment` with `2/2 ready`, `cems-service`, `cems-ingress` with assigned AWS ALB address, and `cems-hpa`.

---

### Demo 5: Live Application on AWS Cloud
- **Concept Proved**: Full production deployment on AWS Cloud.
- **Actions**:
  1. Retrieve the ALB hostname:
     ```bash
     kubectl get ingress cems-ingress -n cems -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
     ```
  2. Paste hostname in browser (`http://<ALB-HOSTNAME>`).
  3. Perform live interactions:
     - View Upcoming Events list.
     - Register a new student account (`/register`).
     - Register for an event.
     - Download the generated PDF Entry Pass.
     - Log in as Admin (`admin@campus.edu` / `admin123`) and view Admin Dashboard.
- **Screenshot 5 to Capture**: Browser showing CEMS homepage with the AWS ALB URL visible in the address bar.
- **Screenshot 6 to Capture**: Generated PDF entry pass downloaded and opened in browser.

---

### Demo 6: Kubernetes Self-Healing Demonstration
- **Concept Proved**: High availability, replica reconciliation, and self-healing.
- **Commands**:
  ```bash
  # Step 1: List running pods
  kubectl get pods -n cems

  # Step 2: In a split terminal, start watching pods
  kubectl get pods -n cems -w

  # Step 3: Delete one of the active pods
  kubectl delete pod <POD-NAME> -n cems
  ```
- **What Evaluator Sees**: The deleted pod enters `Terminating` state, and Kubernetes instantly spins up a brand-new pod (`ContainerCreating` → `Running` → `1/1 Ready`) in seconds. The website remains 100% accessible with zero downtime.
- **Screenshot 7 to Capture**: Terminal output showing the deleted pod terminating and the new replacement pod running.

---

### Demo 7: Elastic Autoscaling Demonstration (HPA)
- **Concept Proved**: Elastic cloud computing, resource threshold monitoring, and automated scale-out.
- **Commands**:
  ```bash
  # Terminal 1: Watch HPA and pods
  kubectl get hpa,pods -n cems -w

  # Terminal 2: Generate synthetic load on the health endpoint
  # Using kubectl run with busybox / curl loop:
  kubectl run load-generator --rm -it --image=busybox -n cems -- /bin/sh -c \
    "while true; do wget -q -O- http://cems-service/health; done"
  ```
- **What Evaluator Sees**: Within 60 seconds, CPU utilization surpasses the 70% threshold. HPA triggers replica scale-up from 2 to 4, 6, up to 8 pods.
- **Screenshot 8 to Capture**: `kubectl get hpa -n cems` displaying `TARGETS: 120%/70%` and `REPLICAS: 4`.

---

### Demo 8: Jenkins CI/CD Automated Pipeline
- **Concept Proved**: End-to-end continuous integration and continuous deployment.
- **Actions**:
  1. Make a minor text change in `templates/about.html` (e.g. update footer or heading).
  2. Commit and push:
     ```bash
     git add templates/about.html
     git commit -m "feat: update event guidelines for college demo"
     git push origin main
     ```
  3. Open Jenkins UI: `http://<JENKINS-IP>:8080/job/CEMS-Pipeline`.
- **What Evaluator Sees**: The build automatically triggers. All stages transition to GREEN:
  - Checkout SCM → Install Dependencies → Flake8 Linting → Bandit Security → Pytest Tests → Docker Build → Trivy Scan → Push to ECR → Deploy to EKS → Rollout Verification → Smoke Tests.
- **Screenshot 9 to Capture**: Jenkins Stage View showing all 12 stages in green.

---

### Demo 9: Prometheus & Grafana Monitoring Dashboard
- **Concept Proved**: Application performance monitoring (APM), service level indicators (SLI), and cluster observability.
- **Actions**:
  1. Access Grafana via port-forward:
     ```bash
     kubectl port-forward svc/cems-monitoring-grafana -n monitoring 3000:80
     ```
  2. Open `http://localhost:3000` in browser (User: `admin`, Pass: `AdminCemsSecurePass2026!`).
  3. Open the **CEMS Production Application Dashboard**.
- **What Evaluator Sees**:
  - Live HTTP throughput (req/sec).
  - P95 and P99 latency percentiles.
  - Pod CPU and Memory utilization.
  - Active replica counts tracking the HPA scale-out.
- **Screenshot 10 to Capture**: Full Grafana dashboard showing live metrics graphs and panels.
