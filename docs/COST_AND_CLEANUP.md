# AWS Cost Management & Teardown Guide

## 1. AWS Cost Breakdown for Student Mini-Projects

The following table provides estimated costs for running the CEMS infrastructure in the AWS `ap-south-1` (Mumbai) region for testing and academic demonstration.

| AWS Resource | Sizing / Tier | Free Tier Eligible? | Estimated Hourly Cost | Estimated Cost (for 10 Hours of Demo) |
|---|---|---|---|---|
| **Amazon EKS Control Plane** | 1 Managed Cluster | ❌ No | ~$0.10 / hour | ~$1.00 |
| **EC2 Worker Nodes** | 2x `t3.medium` (2 vCPU, 4GB RAM) | ❌ No | ~$0.0416 / hr / node ($0.0832 total) | ~$0.83 |
| **AWS Application Load Balancer** | 1 ALB (Internet-Facing) | ❌ No (after 12 mo) | ~$0.0225 / hr + LCU | ~$0.25 |
| **AWS NAT Gateway** | 1 NAT Gateway (Outbound VPC traffic) | ❌ No | ~$0.045 / hr + data | ~$0.45 |
| **Amazon RDS for MySQL** | `db.t4g.micro` or `db.t3.micro` | ✅ Yes (750 hrs/mo free for 12 mos) | $0.00 (Free Tier) or ~$0.018/hr | ~$0.00 – $0.18 |
| **Amazon ECR** | Container Storage (< 1 GB) | ✅ Yes (500 MB/mo free) | Negligible (< $0.05) | ~$0.01 |
| **EBS Volumes (gp3)** | 20 GB root volume per node | ✅ Yes (30 GB/mo free) | Negligible (< $0.10) | ~$0.05 |
| **Jenkins EC2 Server** | 1x `t3.medium` (Ubuntu) | ❌ (Free tier is t2/t3.micro) | ~$0.0416 / hour | ~$0.42 |
| **TOTAL ESTIMATE** | Complete Cloud Architecture | — | **~$0.33 – $0.35 / hour** | **~$3.00 – $3.50 total** |

> [!IMPORTANT]
> Running this infrastructure for 1 full month continuously would cost approximately **$180 – $220 USD**.
> Therefore, **ALWAYS run the cleanup script immediately after concluding your college presentation or evaluation.**

---

## 2. Cost-Reduction Strategies for Students

1. **Use Single-AZ NAT Gateway or Public Node Subnets**: If running strictly for a demo, assign public IPs to worker nodes to eliminate the $32/month NAT Gateway cost.
2. **Stop the Jenkins EC2 Instance**: When not running builds, stop the Jenkins EC2 instance from the AWS EC2 Console to pause compute charges.
3. **Scale Nodes to Zero When Idle**:
   ```bash
   eksctl scale nodegroup --cluster=cems-cluster --name=cems-nodes --nodes=0 --region=ap-south-1
   ```
4. **Use Spot Instances for Worker Nodes**: Spot instances provide up to 70% discount:
   ```bash
   eksctl create cluster --name cems-cluster --node-type t3.medium --spot --nodes 2
   ```

---

## 3. Complete Teardown & Resource Cleanup

To stop all recurring charges permanently, execute the teardown steps in the exact order shown below.

### Method A: Automated Script Execution

#### Linux / macOS / WSL:
```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

#### Windows PowerShell:
```powershell
.\scripts\cleanup.ps1
```

---

### Method B: Manual Step-by-Step Command Execution

If you prefer to execute commands manually:

#### Step 1: Delete Kubernetes Ingress (Deprovisions the AWS ALB)
```bash
kubectl delete ingress cems-ingress -n cems
```
*Wait 2 minutes for AWS Load Balancer Controller to delete the Application Load Balancer and Target Groups.*

#### Step 2: Delete Monitoring Stack (Releases Persistent Volumes)
```bash
helm uninstall cems-monitoring -n monitoring
kubectl delete namespace monitoring
```

#### Step 3: Delete Application Namespace
```bash
kubectl delete namespace cems
```

#### Step 4: Delete Amazon EKS Cluster and Worker Nodes
```bash
eksctl delete cluster --name cems-cluster --region ap-south-1
```
*This command invokes AWS CloudFormation to automatically delete the Managed Node Group, EC2 instances, Auto Scaling Groups, VPC, and EKS Control Plane.*

#### Step 5: Delete Amazon RDS Database Instance
```bash
aws rds delete-db-instance \
  --db-instance-identifier cems-mysql-db \
  --skip-final-snapshot \
  --delete-automated-backups \
  --region ap-south-1
```

#### Step 6: Delete Amazon ECR Repository and Images
```bash
aws ecr delete-repository --repository-name cems-app --force --region ap-south-1
```

#### Step 7: Terminate the Jenkins EC2 Instance
```bash
aws ec2 terminate-instances --instance-ids <YOUR-JENKINS-INSTANCE-ID> --region ap-south-1
```

---

## 4. Post-Cleanup Verification Checklist (AWS Console)

Log into the AWS Management Console (`ap-south-1` Mumbai) and verify that each service shows **0 active billable resources**:

- [ ] **Amazon EC2**:
  - Instances: All instances in `terminated` or `stopped` state.
  - Load Balancers: No active Application Load Balancers.
  - Target Groups: No leftover target groups.
  - Elastic IPs: No unattached Elastic IPs (unattached EIPs incur an hourly fee!).
  - NAT Gateways: Status shows `deleted`.
  - Volumes: No unattached EBS volumes (`available`).
- [ ] **Amazon EKS**: Clusters list is empty.
- [ ] **Amazon RDS**: Databases list is empty.
- [ ] **Amazon ECR**: Repository `cems-app` is deleted.
- [ ] **CloudFormation**: Stacks named `eksctl-cems-cluster-...` show `DELETE_COMPLETE`.
