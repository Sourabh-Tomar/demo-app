pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  serviceAccountName: default
  containers:
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - cat
    tty: true
  - name: terraform
    image: hashicorp/terraform:latest
    command:
    - cat
    tty: true
  - name: azure-cli
    image: mcr.microsoft.com/azure-cli:latest
    command:
    - cat
    tty: true
  volumes:
  - name: docker-sock
    emptyDir: {}
'''
        }
    }

    environment {
        ACR_LOGIN_SERVER = credentials('acr-login-server')
        ACR_CREDENTIALS = credentials('acr-credentials')

        ARM_CLIENT_ID = credentials('azure-client-id')
        ARM_CLIENT_SECRET = credentials('azure-client-secret')
        ARM_TENANT_ID = credentials('azure-tenant-id')
        ARM_SUBSCRIPTION_ID = credentials('azure-subscription-id')

        IMAGE_NAME = 'demo-node'
        IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"

        NOTIFICATION_EMAIL = 'shivam.sharma.942533@gmail.com'

        TF_IN_AUTOMATION = 'true'
        TF_INPUT = 'false'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "Checking out code from ${env.GIT_BRANCH}"
                    checkout scm
                }
            }
        }

        stage('Terraform Plan (Optional)') {
            when {
                anyOf {
                    branch 'main'
                    expression { params.RUN_TERRAFORM == true }
                }
            }
            steps {
                container('terraform') {
                    dir('infra/terraform') {
                        script {
                            echo "Running Terraform plan..."
                            sh '''
                                terraform init -upgrade
                                terraform plan -var="prefix=dstdemo" -out=tfplan
                            '''
                        }
                    }
                }
            }
        }

        stage('Terraform Apply (Manual Approval)') {
            when {
                allOf {
                    branch 'main'
                    expression { params.RUN_TERRAFORM == true }
                    expression { params.APPROVE_TERRAFORM == true }
                }
            }
            steps {
                container('terraform') {
                    dir('infra/terraform') {
                        script {
                            echo "Applying Terraform changes..."
                            sh '''
                                terraform apply -auto-approve tfplan
                            '''
                            env.ACR_LOGIN_SERVER = sh(
                                script: 'terraform output -raw acr_login_server',
                                returnStdout: true
                            ).trim()
                        }
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                container('docker') {
                    withCredentials([usernamePassword(credentialsId: 'acr-credentials', usernameVariable: 'ACR_USERNAME', passwordVariable: 'ACR_PASSWORD')]) {
                        sh '''
                            set -eu
                            echo "Authenticating with Azure Container Registry..."
                            set +x
                            echo "$ACR_PASSWORD" | docker login "$ACR_LOGIN_SERVER" --username "$ACR_USERNAME" --password-stdin
                            set -x
                            echo "Building Docker image: $ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
                            docker buildx build --platform linux/amd64 \
                                -t "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG" \
                                -t "$ACR_LOGIN_SERVER/$IMAGE_NAME:latest" \
                                --push .
                            docker logout "$ACR_LOGIN_SERVER"
                        '''
                    }
                }
            }
        }

        stage('Push to ACR') {
            steps {
                script {
                    echo 'Image push is handled as part of the Docker build stage; no additional action required.'
                }
            }
        }

        stage('Update Kubernetes Manifests') {
            steps {
                script {
                    echo "Updating deployment manifests with new image tag..."
                    sh '''
                        set -euo pipefail
                        sed -i "s|image: .*demo-node:.*|image: ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}|g" \
                            k8s/app/deployment.yaml
                    '''
                }
            }
        }

        stage('Deploy to AKS') {
            when {
                branch 'main'
            }
            steps {
                container('azure-cli') {
                    script {
                        echo "Configuring kubectl for AKS..."
                        sh """
                            az login --service-principal \
                                --username \${ARM_CLIENT_ID} \
                                --password \${ARM_CLIENT_SECRET} \
                                --tenant \${ARM_TENANT_ID}
                            
                            az account set --subscription \${ARM_SUBSCRIPTION_ID}
                            
                            az aks get-credentials \
                                --resource-group dstdemo-rg \
                                --name dstdemo-aks \
                                --overwrite-existing
                        """
                    }
                }
                container('kubectl') {
                    script {
                        echo "Deploying application to AKS..."
                        sh """
                            # Apply namespace if it doesn't exist
                            kubectl apply -f k8s/app/namespace.yaml
                            
                            # Apply configuration
                            kubectl apply -f k8s/app/configmap.yaml
                            kubectl apply -f k8s/app/secret.yaml
                            
                            # Deploy application
                            kubectl apply -f k8s/app/deployment.yaml
                            kubectl apply -f k8s/app/service.yaml
                            kubectl apply -f k8s/app/ingress.yaml
                            
                            # Wait for rollout to complete
                            kubectl -n app rollout status deployment/demo-node --timeout=5m
                            
                            # Verify deployment
                            kubectl -n app get pods
                            kubectl -n app get svc
                            kubectl -n app get ingress
                        """
                    }
                }
            }
        }

        stage('Smoke Test') {
            when {
                branch 'main'
            }
            steps {
                container('kubectl') {
                    script {
                        echo "Running smoke tests..."
                        sh """
                            # Wait for pods to be ready
                            kubectl -n app wait --for=condition=ready pod \
                                -l app.kubernetes.io/name=demo-node \
                                --timeout=300s
                            
                            # Get pod name and test the endpoint
                            POD=\$(kubectl -n app get pod -l app.kubernetes.io/name=demo-node -o jsonpath='{.items[0].metadata.name}')
                            kubectl -n app exec \$POD -- wget -q -O- http://localhost:3000/api/v1/test
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                def deploymentUrl = "https://sourabh.techis.store"
                def jenkinsUrl = "https://sourabh-jenkins.techis.store"
                def recipients = env.NOTIFICATION_EMAIL?.trim()

                if (recipients) {
                    emailext(
                        to: recipients,
                        subject: "Jenkins Build SUCCESS: ${env.JOB_NAME} - Build #${env.BUILD_NUMBER}",
                        body: """
                        <html>
                        <body style="font-family: Arial, sans-serif;">
                            <h2 style="color: #28a745;">Build Successful!</h2>
                            <p><strong>Job:</strong> ${env.JOB_NAME}</p>
                            <p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
                            <p><strong>Git Branch:</strong> ${env.GIT_BRANCH}</p>
                            <p><strong>Git Commit:</strong> ${env.GIT_COMMIT}</p>
                            <p><strong>Image Tag:</strong> ${IMAGE_TAG}</p>
                            <hr>
                            <h3>Deployment Details:</h3>
                            <ul>
                                <li><strong>Application URL:</strong> <a href="${deploymentUrl}">${deploymentUrl}</a></li>
                                <li><strong>Test Endpoint:</strong> <a href="${deploymentUrl}/api/v1/test">${deploymentUrl}/api/v1/test</a></li>
                                <li><strong>Jenkins:</strong> <a href="${jenkinsUrl}">${jenkinsUrl}</a></li>
                            </ul>
                            <hr>
                            <p><strong>Build Duration:</strong> ${currentBuild.durationString}</p>
                            <p><strong>Build URL:</strong> <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                            <p style="color: #666; font-size: 12px;">
                                This is an automated message from Jenkins CI/CD Pipeline.
                            </p>
                        </body>
                        </html>
                    """,
                    mimeType: 'text/html'
                    )
                } else {
                    echo 'NOTIFICATION_EMAIL not set; skipping success notification.'
                }
            }
        }
        
        failure {
            script {
                def recipients = env.NOTIFICATION_EMAIL?.trim()

                if (recipients) {
                    emailext(
                        to: recipients,
                        subject: "Jenkins Build FAILED: ${env.JOB_NAME} - Build #${env.BUILD_NUMBER}",
                        body: """
                        <html>
                        <body style="font-family: Arial, sans-serif;">
                            <h2 style="color: #dc3545;">Build Failed!</h2>
                            <p><strong>Job:</strong> ${env.JOB_NAME}</p>
                            <p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
                            <p><strong>Git Branch:</strong> ${env.GIT_BRANCH}</p>
                            <p><strong>Git Commit:</strong> ${env.GIT_COMMIT}</p>
                            <hr>
                            <h3>Failure Details:</h3>
                            <p>The build has failed. Please check the console output for more details.</p>
                            <p><strong>Build URL:</strong> <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></p>
                            <hr>
                            <p><strong>Build Duration:</strong> ${currentBuild.durationString}</p>
                            <p style="color: #666; font-size: 12px;">
                                This is an automated message from Jenkins CI/CD Pipeline.
                            </p>
                        </body>
                        </html>
                    """,
                    mimeType: 'text/html'
                    )
                } else {
                    echo 'NOTIFICATION_EMAIL not set; skipping failure notification.'
                }
            }
        }
        
        always {
            script {
                echo "Pipeline completed with status: ${currentBuild.result}"
                deleteDir()
            }
        }
    }
}
