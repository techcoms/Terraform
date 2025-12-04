terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }

  # Optional: enable remote state via S3 (recommended for CI)
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "eks/cluster.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "terraform-locks"
  # }
}
