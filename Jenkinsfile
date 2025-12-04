pipeline {
  agent any

  environment {
    AWS_REGION  = "ap-south-1"
    CLUSTER_NAME = "demo-eks-cluster"
  }

  stages {
    stage('Checkout') {
      steps {
        git url: 'https://github.com/techcoms/Terraform.git', branch: 'main'
      }
    }

    stage('Terraform Apply') {
      steps {
        // Bind AWS creds into env vars for Terraform
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh """
            set -euo pipefail
            rm -rf .terraform .terraform.lock.hcl
            terraform init -upgrade
            terraform plan -out=tfplan
            terraform apply -auto-approve tfplan
          """
        }
      }
    }

    stage('Update Kubeconfig') {
      steps {
        // Re-bind creds for aws cli usage
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv(["AWS_REGION=${env.AWS_REGION}", "AWS_DEFAULT_REGION=${env.AWS_REGION}"]) {
            sh '''
              set -euo pipefail
              aws sts get-caller-identity
              aws eks update-kubeconfig --region $AWS_REGION --name ${CLUSTER_NAME}
            '''
          }
        }
      }
    }

    stage('Deploy NGINX') {
      steps {
        // Assumes kubeconfig is configured in $HOME/.kube/config by previous step
        sh """
          set -euo pipefail
          kubectl apply -f deploymrnt-ngnix.yaml
          kubectl get pods -l app=nginx
        """
      }
    }
  } 
} 
