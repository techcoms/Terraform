pipeline {
    agent any
    
    environment {
        // Application settings
        APP_NAME          = 'my-java-app'
        WAR_FILE          = 'target/*.war'
        // Docker settings
        DOCKER_IMAGE      = "${APP_NAME}:${BUILD_NUMBER}"
        CONTAINER_NAME    = "test-container-${BUILD_NUMBER}"
        HOST_PORT         = '8083'
        CONTAINER_PORT    = '8080'
        // SonarQube setting
        SONAR_HOST_URL    = 'http://13.126.141.57:9000'
        // AWS Settings
        AWS_DEFAULT_REGION = 'ap-south-1'
        ECR_REPO           = 'my-java-app'
        ECS_CLUSTER        = 'my-production-cluster'
        ECS_SERVICE        = 'my-spring-service'
        AWS_CREDENTIAL_ID  = 'aws-credentials' // ID of "Username with password" credential in Jenkins
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: "feature", url: "https://github.com/techcoms/backend-springboot-maven-jar.git"
            }
        }
        stage('Build') {
            steps {
                sh 'mvn clean compile'
            }
        }
        stage('Unit Tests') {
            steps {
                sh 'mvn clean test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_AUTH_TOKEN')]) {
                    sh """
                        mvn sonar:sonar \
                          -Dsonar.projectKey=spring-boot-demo \
                          -Dsonar.host.url=${SONAR_HOST_URL} \
                          -Dsonar.login=\${SONAR_AUTH_TOKEN}
                    """
                }
            }
        }
        
        stage('Package jar') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }
        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE} ."
            }
        }
        stage('Test Docker Container') {
            steps {
                script {
                    try {
                        sh """
                            docker run -d --name ${CONTAINER_NAME} -p ${HOST_PORT}:${CONTAINER_PORT} ${DOCKER_IMAGE}
                        """
                        timeout(time: 3, unit: 'MINUTES') {
                            waitUntil {
                                script {
                                    def response = sh(
                                        script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:${HOST_PORT}/ || echo '000'",
                                        returnStdout: true
                                    ).trim()
                                    return response == '200'
                                }
                            }
                        }
                        echo "Docker container started and application is responding!"
                    } finally {
                        sh "docker stop ${CONTAINER_NAME} || true"
                        sh "docker rm ${CONTAINER_NAME} || true"
                    }
                }
            }
        }
        stage('Provision Infrastructure (Terraform)') {
            // Run on all branches (feature and main) so verification happens before merge
            steps {
                withCredentials([usernamePassword(credentialsId: AWS_CREDENTIAL_ID, passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh '''#!/usr/bin/env bash
                        set -euo pipefail
                        echo "Initializing Terraform..."
                        # Clean up previous state to avoid conflicts
                        rm -rf .terraform .terraform.lock.hcl || true
                        terraform init -upgrade
                        
                        echo "Planning Infrastructure..."
                        terraform plan -out=tfplan \
                          -var="aws_region=${AWS_DEFAULT_REGION}" \
                          -var="ecr_repo_name=${ECR_REPO}" \
                          -var="ecs_cluster_name=${ECS_CLUSTER}"
                        
                        echo "Applying Infrastructure..."
                        terraform apply -auto-approve tfplan
                        # Capture output or fallback to env var
                        CLUSTER_FROM_TF=$(terraform output -raw ecs_cluster_name 2>/dev/null || true)
                        if [[ -z "$CLUSTER_FROM_TF" ]]; then
                          CLUSTER_FROM_TF="${ECS_CLUSTER}"
                        fi
                        echo "$CLUSTER_FROM_TF" > cluster_name.txt
                        echo "Cluster resolved as: $CLUSTER_FROM_TF"
                    '''
                }
            }
        }
        stage('Create & Merge Pull Request') {
            when {
                not { branch 'main' }
            }
            steps {
                script {
                    withCredentials([string(credentialsId: 'github-creds', variable: 'GITHUB_TOKEN')]) {
                        sh """
                             echo "Creating PR to merge ${env.BRANCH_NAME} into main..."
                             gh pr create --base main --head ${env.BRANCH_NAME} --title "Merge ${env.BRANCH_NAME} to main" --body "Automated PR created by Jenkins" || echo "PR might already exist"
                        """
                        
                        timeout(time: 10, unit: 'MINUTES') {
                            input message: "Infra verified on ${env.BRANCH_NAME}. Merge to main?"
                        }
                        
                        sh """
                            echo "Merging PR for ${env.BRANCH_NAME}..."
                            gh pr merge ${env.BRANCH_NAME} --merge
                        """
                    }
                }
            }
        }
        stage('Push Image to ECR') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([usernamePassword(credentialsId: AWS_CREDENTIAL_ID, passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh """
                        echo "Retrieving ECR details from Terraform..."
                        FULL_REPO_URL=\$(terraform output -raw ecr_repository_url)
                        # Extract the registry domain (everything before the first /)
                        REGISTRY_DOMAIN=\$(echo \$FULL_REPO_URL | cut -d'/' -f1)
                        
                        echo "Logging into ECR: \$REGISTRY_DOMAIN"
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin \$REGISTRY_DOMAIN
                        
                        echo "Pushing image to \$FULL_REPO_URL..."
                        docker tag ${DOCKER_IMAGE} \$FULL_REPO_URL:${BUILD_NUMBER}
                        docker push \$FULL_REPO_URL:${BUILD_NUMBER}
                        
                        docker tag ${DOCKER_IMAGE} \$FULL_REPO_URL:latest
                        docker push \$FULL_REPO_URL:latest
                    """
                }
            }
        }
        stage('Approval for Production') {
            when { branch 'main' }
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input message: 'Review passed? Approve to deploy to PRODUCTION'
                }
            }
        }
        stage('Deploy to Production ECS') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([usernamePassword(credentialsId: AWS_CREDENTIAL_ID, passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh """
                        echo "Updating ECS Service..."
                        aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --force-new-deployment --region ${AWS_DEFAULT_REGION}
                    """
                }
            }
        }
    }
    post {
        always {
            cleanWs(deleteDirs: true)
            sh 'docker rmi ${DOCKER_IMAGE} || true'
        }
    }
}
