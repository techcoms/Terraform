output "cluster_name" {
  value = module.eks.cluster_id
  description = "EKS cluster name"
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --region ${var.region}"
  description = "Command to generate kubeconfig for kubectl"
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
  description = "EKS API endpoint"
}
