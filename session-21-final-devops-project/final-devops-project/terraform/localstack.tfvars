# Used for the local, real `plan`/`apply` against LocalStack (no AWS account, no cost).
# LocalStack community has no EKS API, so the cluster/node group are planned in the full plan
# but excluded from the LocalStack apply.
use_localstack     = true
create_eks         = false
enable_nat_gateway = true
aws_region         = "us-east-1"
azs                = ["us-east-1a", "us-east-1b"]
