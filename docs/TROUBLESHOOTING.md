# CEMS DevOps Troubleshooting & Incident Runbook

This guide contains step-by-step diagnostic workflows for resolving issues across Docker, Kubernetes (EKS), AWS infrastructure, Jenkins CI/CD, and Prometheus/Grafana monitoring.

---

## 1. Quick Diagnostic Triage Commands

Run these commands first to assess the state of the cluster and application:

```bash
# Check pod status and restart counts in the cems namespace
kubectl get pods -n cems -o wide

# Check recent deployment rollouts and events
kubectl describe deployment cems-deployment -n cems

# Inspect cluster-wide events (sorted by timestamp)
kubectl get events -n cems --sort-by='.metadata.creationTimestamp'

# Check application live logs
kubectl logs -n cems -l app.kubernetes.io/name=cems --tail=100 -f

# Check ALB ingress status and assigned address
kubectl get ingress cems-ingress -n cems -o wide
```

---

## 2. Common Kubernetes Issues

### Issue 1: Pod Stuck in `CrashLoopBackOff` or `Error`
- **Symptoms**: `kubectl get pods -n cems` shows STATUS `CrashLoopBackOff` with increasing RESTARTS.
- **Root Causes**:
  1. Missing or invalid database credentials in `cems-secret`.
  2. Database host unreachable (RDS security group blocking port 3306).
  3. Gunicorn syntax or configuration error in `gunicorn.conf.py`.
- **Diagnostic Steps**:
  ```bash
  # 1. Inspect previous terminated container logs
  kubectl logs -n cems <pod-name> --previous

  # 2. Check pod termination reason and exit code
  kubectl describe pod -n cems <pod-name> | grep -A 10 "Last State:"
  ```
- **Remediation**:
  - If error is `Access denied for user 'cems_admin'`, update secret:
    ```bash
    kubectl create secret generic cems-secret -n cems \
      --from-literal=SECRET_KEY="<valid-secret-key>" \
      --from-literal=DB_PASSWORD="<correct-password>" \
      --dry-run=client -o yaml | kubectl apply -f -
    ```
  - Restart deployment pods:
    ```bash
    kubectl rollout restart deployment/cems-deployment -n cems
    ```

---

### Issue 2: Pod Stuck in `ImagePullBackOff` or `ErrImagePull`
- **Symptoms**: Pod cannot pull container image from Amazon ECR.
- **Root Causes**:
  1. EC2 worker node IAM role lacks `AmazonEC2ContainerRegistryReadOnly` policy.
  2. The image tag specified in `k8s/deployment.yaml` does not exist in ECR.
  3. AWS Account ID or Region in image URI is incorrect.
- **Diagnostic Steps**:
  ```bash
  kubectl describe pod -n cems <pod-name> | grep -A 5 "Events:"
  ```
- **Remediation**:
  - Verify the image exists in ECR:
    ```bash
    aws ecr list-images --repository-name cems-app --region ap-south-1
    ```
  - Attach read-only policy to the EKS node instance role:
    ```bash
    aws iam attach-role-policy \
      --role-name <eks-node-instance-role> \
      --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
    ```

---

### Issue 3: Ingress / AWS ALB Returns `502 Bad Gateway`
- **Symptoms**: Visiting the ALB URL returns HTTP 502.
- **Root Causes**:
  1. Application pods are not listening on port 5000.
  2. ALB target group health check failing on `/health`.
  3. Pods are crashing immediately upon receiving requests.
- **Diagnostic Steps**:
  ```bash
  # Check AWS Load Balancer Controller logs
  kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

  # Test pod directly via port-forward
  kubectl port-forward svc/cems-service -n cems 5000:80
  curl -I http://127.0.0.1:5000/health
  ```
- **Remediation**:
  - Ensure the readiness probe in `k8s/deployment.yaml` matches the ALB healthcheck path (`/health` on port 5000).
  - Check security group rules between the ALB security group and worker node security group on port 5000.

---

### Issue 4: HorizontalPodAutoscaler Shows `<unknown>/70%`
- **Symptoms**: `kubectl get hpa -n cems` displays `TARGETS: <unknown>/70%`.
- **Root Causes**:
  1. Kubernetes Metrics Server is not installed or not healthy.
  2. Pod specification lacks `resources.requests.cpu`.
- **Diagnostic Steps**:
  ```bash
  kubectl get pods -n kube-system -l k8s-app=metrics-server
  kubectl top pods -n cems
  ```
- **Remediation**:
  - Reinstall the Metrics Server:
    ```bash
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    ```
  - Verify `resources.requests` exists in `k8s/deployment.yaml`.

---

## 3. Database Connectivity Troubleshooting

### Issue: `Can't connect to MySQL server on ... (110 "Connection timed out")`
- **Root Cause**: The AWS RDS Security Group does not allow inbound TCP traffic on port 3306 from the EKS Node Group security group.
- **Diagnostic Command**:
  ```bash
  # Launch a debugging pod inside EKS to test network connectivity
  kubectl run mysql-client --rm -it --image=mysql:8.0 -n cems -- /bin/sh
  
  # Inside the pod:
  mysql -h <rds-endpoint> -u cems_admin -p
  ```
- **Remediation**:
  1. Navigate to **AWS Console** → **RDS** → **Databases** → `cems-mysql-db`.
  2. Click the **VPC security groups** link under **Connectivity & security**.
  3. Under **Inbound rules**, click **Edit inbound rules**.
  4. Add Rule:
     - Type: `MySQL/Aurora` (Port: 3306)
     - Source: Select the Security Group of your EKS Managed Node Group (`cems-cluster-node-group-...`).
  5. Save rules.

---

## 4. Jenkins CI/CD Troubleshooting

### Issue 1: `permission denied while trying to connect to the Docker daemon socket`
- **Root Cause**: The `jenkins` user is not part of the `docker` group.
- **Remediation**:
  ```bash
  sudo usermod -aG docker jenkins
  sudo systemctl restart jenkins
  ```

### Issue 2: `aws: command not found` or `kubectl: command not found` in Pipeline
- **Root Cause**: Tool binaries are not in Jenkins PATH (`/usr/local/bin` or `/usr/bin`).
- **Remediation**:
  In Jenkins: **Manage Jenkins** → **System** → **Global properties** → **Environment variables**:
  - Name: `PATH`
  - Value: `/usr/local/bin:/usr/bin:/bin:$PATH`

### Issue 3: ECR Push Fails with `The authorization header is malformed`
- **Root Cause**: The Jenkins server does not have an IAM instance profile or valid AWS credentials.
- **Remediation**:
  Attach an IAM Role with `AmazonEC2ContainerRegistryPowerUser` to the Jenkins EC2 instance.

---

## 5. Prometheus and Grafana Troubleshooting

### Issue: CEMS Target Shows `DOWN (0/1)` in Prometheus
- **Root Cause**: Prometheus ServiceMonitor cannot scrape port `http` or the `/metrics` endpoint is protected by CSRF or returns 404.
- **Diagnostic Command**:
  ```bash
  # Check if ServiceMonitor matches the service labels
  kubectl get servicemonitor -n monitoring cems-service-monitor -o yaml
  kubectl get svc -n cems cems-service --show-labels
  ```
- **Remediation**:
  - Ensure `cems-service` has the label `app.kubernetes.io/name: cems`.
  - Verify `app.py` has `ENABLE_METRICS=true` and `/metrics` responds with HTTP 200.
