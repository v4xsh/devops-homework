# Used for the local, real `plan`/`apply` against LocalStack (no AWS account, no cost).
# LocalStack community has no EKS and no ECR API, so those resources appear in the full plan
# (scripts/06-terraform.sh, screenshot 22) but are switched off for the LocalStack apply.
use_localstack     = true
create_eks         = false
create_ecr         = false
enable_nat_gateway = true
aws_region         = "us-east-1"
azs                = ["us-east-1a", "us-east-1b"]
