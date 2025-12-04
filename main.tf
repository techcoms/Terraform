provider "aws" {
  region = var.region
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 19.0.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version
  subnets         = null  # let module create a VPC when create_vpc = true

  # Let module create VPC automatically
  create_vpc = true

  # node group (managed node group)
  node_groups = {
    default = {
      desired_capacity = var.node_desired_capacity
      min_capacity     = 1
      max_capacity     = 3
      instance_type    = var.node_instance_type
      # optionally attach additional tags, iam policies etc.
    }
  }

  tags = {
    Environment = "dev"
    Project     = "jenkins-eks"
  }
}
