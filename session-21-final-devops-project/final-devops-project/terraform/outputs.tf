output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  description = "EKS cluster name (null when create_eks = false)"
  value       = var.create_eks ? aws_eks_cluster.main[0].name : null
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint"
  value       = var.create_eks ? aws_eks_cluster.main[0].endpoint : null
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by name"
  value       = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}

output "artifacts_bucket" {
  description = "S3 bucket for artifacts and Terraform state"
  value       = aws_s3_bucket.artifacts.bucket
}

output "kubeconfig_command" {
  description = "Command to point kubectl at the new cluster"
  value       = var.create_eks ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main[0].name}" : null
}
