pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
        AWS_ACCOUNT_ID     = credentials('aws-account-id') // Or configured as Jenkins Global Variable
        ECR_REPO_NAME      = 'cems-app'
        EKS_CLUSTER_NAME   = 'cems-cluster'
        K8S_NAMESPACE      = 'cems'
        IMAGE_TAG          = "${GIT_COMMIT.take(8)}"
        ECR_REGISTRY       = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
        FULL_IMAGE_NAME    = "${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '15'))
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
        ansiColor('xterm')
    }

    stages {
        stage('Checkout SCM') {
            steps {
                echo "Checking out CEMS repository at commit: ${GIT_COMMIT}"
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                echo "Setting up Python virtual environment and installing dependencies..."
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements-dev.txt
                '''
            }
        }

        stage('Static Analysis & Linting') {
            steps {
                echo "Running flake8 code style checks..."
                sh '''
                    . .venv/bin/activate
                    flake8 tests/ gunicorn.conf.py
                '''
            }
        }

        stage('Application Security Scan') {
            steps {
                echo "Running Bandit Static Application Security Testing (SAST)..."
                sh '''
                    . .venv/bin/activate
                    bandit -c bandit.yaml -r tests/ gunicorn.conf.py
                '''
            }
        }

        stage('Automated Unit Tests') {
            steps {
                echo "Executing Pytest test suite..."
                sh '''
                    . .venv/bin/activate
                    python -m pytest tests/test_app.py -v --junitxml=test-results.xml
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-results.xml'
                }
            }
        }

        stage('Docker Build') {
            steps {
                echo "Building production Docker image: ${FULL_IMAGE_NAME}"
                sh """
                    docker build -t ${FULL_IMAGE_NAME} -t ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest .
                """
            }
        }

        stage('Image Vulnerability Scan (Trivy)') {
            steps {
                echo "Scanning container image with Trivy..."
                sh """
                    trivy image --exit-code 0 --severity MEDIUM,HIGH,CRITICAL ${FULL_IMAGE_NAME}
                """
            }
        }

        stage('Push to Amazon ECR') {
            steps {
                echo "Authenticating with Amazon ECR and pushing image..."
                sh """
                    aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker push ${FULL_IMAGE_NAME}
                    docker push ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest
                """
            }
        }

        stage('Validate Kubernetes Manifests') {
            steps {
                echo "Validating Kubernetes manifests syntax..."
                sh """
                    python3 -c "
import glob, yaml
files = glob.glob('k8s/**/*.yaml', recursive=True) + glob.glob('k8s/*.yaml')
for f in set(files):
    with open(f) as fp:
        list(yaml.safe_load_all(fp))
print('Manifest validation passed.')
"
                """
            }
        }

        stage('Deploy to Amazon EKS') {
            steps {
                echo "Updating kubeconfig and deploying to EKS cluster: ${EKS_CLUSTER_NAME}..."
                sh """
                    aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}
                    kubectl apply -f k8s/namespace.yaml
                    kubectl apply -f k8s/configmap.yaml
                    kubectl apply -f k8s/service.yaml
                    kubectl apply -f k8s/ingress.yaml
                    kubectl apply -f k8s/autoscaling.yaml
                    kubectl apply -f k8s/pdb.yaml
                    kubectl apply -f k8s/networkpolicy.yaml

                    # Update container image to the immutable Git commit tag
                    kubectl set image deployment/cems-deployment cems-app=${FULL_IMAGE_NAME} -n ${K8S_NAMESPACE}
                """
            }
        }

        stage('Verify Rollout Status') {
            steps {
                echo "Waiting for zero-downtime rolling update to complete..."
                sh """
                    kubectl rollout status deployment/cems-deployment -n ${K8S_NAMESPACE} --timeout=180s
                """
            }
        }

        stage('Deployment Smoke Tests') {
            steps {
                echo "Running post-deployment smoke tests against active Ingress/Service..."
                sh """
                    # Retrieve ALB hostname or cluster service IP
                    ALB_HOST=\$(kubectl get ingress cems-ingress -n ${K8S_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                    if [ -z "\$ALB_HOST" ]; then
                        echo "ALB Hostname not yet populated, falling back to port-forward for smoke tests..."
                        kubectl port-forward svc/cems-service -n ${K8S_NAMESPACE} 5000:80 &
                        PF_PID=\$!
                        sleep 3
                        . .venv/bin/activate
                        python tests/test_smoke.py http://127.0.0.1:5000
                        kill \$PF_PID || true
                    else
                        echo "Testing against public ALB: http://\$ALB_HOST"
                        . .venv/bin/activate
                        python tests/test_smoke.py "http://\$ALB_HOST"
                    fi
                """
            }
        }
    }

    post {
        success {
            echo "SUCCESS: CEMS CI/CD Pipeline completed successfully! Image: ${FULL_IMAGE_NAME}"
        }
        failure {
            echo "FAILURE: Pipeline failed! Initiating rollback to previous deployment..."
            sh """
                aws eks update-kubeconfig --region ${env.AWS_DEFAULT_REGION} --name ${env.EKS_CLUSTER_NAME} || true
                kubectl rollout undo deployment/cems-deployment -n ${env.K8S_NAMESPACE} || true
                kubectl rollout status deployment/cems-deployment -n ${env.K8S_NAMESPACE} --timeout=60s || true
            """
        }
        
    }
}
