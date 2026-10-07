output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "security_group_id" {
  description = "ID of the web security group."
  value       = aws_security_group.web.id
}

output "ami_id" {
  description = "AMI the instance was launched from."
  value       = local.ami_id
}

output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IPv4 of the EC2 instance."
  value       = aws_instance.web.public_ip
}

output "website_url" {
  description = "URL of the nginx page."
  value       = "http://${aws_instance.web.public_ip}"
}

output "artifact_bucket" {
  description = "S3 bucket for logs/artifacts."
  value       = aws_s3_bucket.artifacts.bucket
}

output "user_data_artifact_key" {
  description = "S3 key of the stored bootstrap script."
  value       = aws_s3_object.user_data_artifact.key
}
