variable "project" {
  description = "Name prefix for every resource"
  type        = string
  default     = "taskboard"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "azs" {
  description = "Two availability zones for the subnets"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnets (load balancers, NAT gateway)"
  type        = list(string)
  default     = ["10.20.101.0/24", "10.20.102.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnets (EKS worker nodes)"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "enable_nat_gateway" {
  description = "Create one NAT gateway so private nodes can pull images (costs money on real AWS)"
  type        = bool
  default     = true
}

variable "create_eks" {
  description = "Create the EKS cluster + node group (set false for LocalStack community, which has no EKS)"
  type        = bool
  default     = true
}

variable "cluster_version" {
  description = "Kubernetes version of the EKS control plane"
  type        = string
  default     = "1.33"
}

variable "cluster_endpoint_public_access" {
  description = "Expose the EKS API endpoint publicly (off by default: reach it through a VPN / bastion in the VPC)"
  type        = bool
  default     = false
}

variable "cluster_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint (only used when cluster_endpoint_public_access = true)"
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  description = "EC2 instance types of the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "create_ecr" {
  description = "Create the ECR repositories (set false for LocalStack community, where ECR is a Pro-only service)"
  type        = bool
  default     = true
}

variable "ecr_repositories" {
  description = "Container repositories to create"
  type        = list(string)
  default     = ["taskboard-backend", "taskboard-frontend"]
}

variable "artifacts_bucket_name" {
  description = "Globally unique S3 bucket for build artifacts / reports / Terraform state"
  type        = string
  default     = "vansh-10099-taskboard-artifacts"
}

variable "use_localstack" {
  description = "Point the AWS provider at LocalStack instead of real AWS"
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "LocalStack edge endpoint"
  type        = string
  default     = "http://localhost:4566"
}
