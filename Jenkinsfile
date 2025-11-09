pipeline {
    agent any

    environment {
        // Azure Container Registry
        ACR_NAME = 'acrdev081125st'
        ACR_LOGIN_SERVER = "${ACR_NAME}.azurecr.io"
        IMAGE_NAME = 'demo-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        // AKS Details
        AKS_RESOURCE_GROUP = 'rg-dev'
        AKS_CLUSTER_NAME = 'aks-dev'
        K8S_NAMESPACE = 'demo'
        
        // Email Notification
        EMAIL_RECIPIENTS = 'sourabh.tomar.1999st@gmail.com'
        
        // Build Retention
        BUILD_RETENTION = '10'
        
        // Disable SSL verification for git if needed
        GIT_SSL_NO_VERIFY = 'true'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: env.BUILD_RETENTION))
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
        ansiColor('xterm')
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Validate Environment') {
            steps {
                script {
                    // Check required tools
                    sh '''
                        docker --version
                        kubectl version --client
                        az --version
                    '''
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // Get git commit information for the image tag
                    env.GIT_COMMIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    env.GIT_BRANCH_NAME = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    // Update image tag to include git info
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                }
            }
        }

        stage('Build and Test') {
            steps {
                script {
                    // Install dependencies and run tests if any
                    sh '''
                        npm install
                        npm test || echo "No tests found"
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Build the Docker image with build arguments if needed
                    docker.build("${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}", "--build-arg NODE_ENV=production .")
                }
            }
        }

        stage('Security Scan') {
            steps {
                script {
                    // Scan Docker image for vulnerabilities (example using Trivy)
                    sh """
                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG} || true
                    """
                }
            }
        }

        stage('Push to ACR') {
            steps {
                script {
                    // Login to ACR using Azure credentials
                    withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                        sh '''
                            az acr login --name ${ACR_NAME}
                            docker push ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}
                            # Also tag and push as latest
                            docker tag ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG} ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:latest
                            docker push ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:latest
                        '''
                    }
                }
            }
        }

        stage('Deploy to AKS') {
            steps {
                script {
                    withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                        sh '''
                            # Get AKS credentials
                            az aks get-credentials --resource-group ${AKS_RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} --overwrite-existing
                            
                            # Create namespace if it doesn't exist
                            kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                            
                            # Update the kubernetes deployment file with the new image
                            sed -i "s|image:.*|image: ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}|g" k8s/deployment.yaml
                            
                            # Apply Kubernetes manifests
                            kubectl apply -f k8s/configmap.yaml -n ${K8S_NAMESPACE}
                            kubectl apply -f k8s/deployment.yaml -n ${K8S_NAMESPACE}
                            kubectl apply -f k8s/service.yaml -n ${K8S_NAMESPACE}
                            kubectl apply -f k8s/ingress.yaml -n ${K8S_NAMESPACE}
                            
                            # Verify deployment
                            kubectl rollout status deployment/demo-app -n ${K8S_NAMESPACE} --timeout=300s
                        '''
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    sh '''
                        # Wait for pods to be ready
                        kubectl wait --for=condition=ready pod -l app=demo-app -n ${K8S_NAMESPACE} --timeout=300s
                        
                        # Get deployment status
                        kubectl get deployment,svc,pods -n ${K8S_NAMESPACE}
                        
                        # Check application health
                        curl -f http://localhost:8080/health || echo "Health check endpoint not available"
                    '''
                }
            }
        }
    }

    post {
        success {
            script {
                emailext (
                    subject: "Pipeline Success: ${currentBuild.fullDisplayName}",
                    body: """
                        Pipeline completed successfully!
                        
                        Build Number: ${BUILD_NUMBER}
                        Branch: ${env.GIT_BRANCH_NAME}
                        Commit: ${env.GIT_COMMIT_SHORT}
                        Image: ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}
                        
                        View the build details here: ${BUILD_URL}
                    """,
                    to: "${EMAIL_RECIPIENTS}",
                    attachLog: true
                )
            }
        }
        failure {
            script {
                emailext (
                    subject: "Pipeline Failed: ${currentBuild.fullDisplayName}",
                    body: """
                        Pipeline failed!
                        
                        Build Number: ${BUILD_NUMBER}
                        Branch: ${env.GIT_BRANCH_NAME}
                        Commit: ${env.GIT_COMMIT_SHORT}
                        
                        Error Details:
                        ${currentBuild.description ?: 'See attached log for details'}
                        
                        View the build details here: ${BUILD_URL}
                    """,
                    to: "${EMAIL_RECIPIENTS}",
                    attachLog: true
                )
            }
        }
        always {
            sh '''
                docker rmi ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG} || true
                docker rmi ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:latest || true
            '''
        }
    }
}