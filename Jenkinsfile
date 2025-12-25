pipeline {
  agent any

  environment {
    AWS_REGION   = "ap-south-1"
    CLUSTER_NAME = "demo-eks-cluster" // fallback
  }

  stages {

    stage('Checkout') {
      steps {
        git url: 'https://github.com/techcoms/Terraform.git', branch: 'main'
      }
    }

    stage('Terraform Apply') {
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: 'aws-creds',
            usernameVariable: 'AWS_ACCESS_KEY_ID',
            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
          )
        ]) {
          sh '''#!/usr/bin/env bash
            set -euo pipefail

            echo "Initializing Terraform..."
            rm -rf .terraform .terraform.lock.hcl || true

            terraform init -upgrade
            terraform plan -out=tfplan
            terraform apply -auto-approve tfplan

            CLUSTER_FROM_TF=$(terraform output -raw cluster_name 2>/dev/null || true)

            if [[ -z "$CLUSTER_FROM_TF" ]]; then
              CLUSTER_FROM_TF="${CLUSTER_NAME}"
            fi

            echo "$CLUSTER_FROM_TF" > cluster_name.txt
            echo "Cluster resolved as: $CLUSTER_FROM_TF"
          '''
        }
      }
    }

    stage('Update Kubeconfig & Deploy') {
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: 'aws-creds',
            usernameVariable: 'AWS_ACCESS_KEY_ID',
            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
          )
        ]) {
          sh '''#!/usr/bin/env bash
            set -euo pipefail

            export AWS_DEFAULT_REGION=${AWS_REGION}
            CLUSTER=$(cat cluster_name.txt)

            echo "Using cluster: $CLUSTER"

            aws sts get-caller-identity
            aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER"

            kubectl apply -f deployment-ngnix.yaml
            kubectl get pods -l app=nginx
          '''
        }
      }
    }
  }

  post {
    always {
      sh '''#!/usr/bin/env bash
        set +e

        if [[ -f cluster_name.txt ]]; then
          CLUSTER=$(cat cluster_name.txt)
          echo "Pipeline finished for cluster: $CLUSTER"
          kubectl get nodes || true
        fi
      '''
    }
  }
}
