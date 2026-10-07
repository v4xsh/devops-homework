aws_region         = "ap-south-1"
project            = "s19-vansh"
vpc_cidr           = "10.19.0.0/16"
public_subnet_cidr = "10.19.1.0/24"
instance_type      = "t2.micro"
bucket_name        = "vansh-dobhal-10099-s19-artifacts"

# SSH source. 203.0.113.10 is from TEST-NET-3 (RFC 5737, reserved for docs):
# the run was on LocalStack, which does not enforce security groups, and a real
# home IP should not be committed to a public repo. On real AWS use:
#   terraform apply -var "my_ip=$(curl -s https://checkip.amazonaws.com)/32"
my_ip = "203.0.113.10/32"

# Executed against LocalStack (no AWS account used). For real AWS: export
# credentials and set this to false.
use_localstack = true
