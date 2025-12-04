variable "region" { default = "ap-south-1" }
variable "cluster_name" { default = "demo-eks-cluster" }
variable "node_instance_type" { default = "t3.medium" }
variable "node_desired_capacity" { type = number, default = 1 }
