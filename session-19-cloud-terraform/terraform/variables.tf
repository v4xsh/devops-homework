variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Name prefix used for every resource."
  type        = string
  default     = "s19-vansh"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.19.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block of the public subnet (must be inside vpc_cidr)."
  type        = string
  default     = "10.19.1.0/24"
}

variable "my_ip" {
  description = "Your public IP in CIDR form (x.x.x.x/32). Only this address may SSH (port 22)."
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip, 0)) && endswith(var.my_ip, "/32")
    error_message = "my_ip must be a single IPv4 address in CIDR form, e.g. 198.51.100.7/32."
  }
}

variable "instance_type" {
  description = "EC2 instance type (t2.micro is Free Tier eligible)."
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "Optional fixed AMI ID. Empty = look up the latest Canonical Ubuntu amd64 AMI."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Optional existing EC2 key pair name for SSH. null = no key pair."
  type        = string
  default     = null
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for logs/artifacts."
  type        = string
}

variable "use_localstack" {
  description = "true = send all API calls to LocalStack instead of real AWS."
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "LocalStack edge endpoint (only used when use_localstack = true)."
  type        = string
  default     = "http://localhost:4566"
}
