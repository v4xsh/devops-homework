#!/usr/bin/env bash
# Full Terraform workflow for session-19 against LocalStack, captured with snap.
set -u
S=~/devops-homework/session-19-cloud-terraform
T=$S/terraform
export PATH="$HOME/.local/bin:$PATH"
# Keep the provider download out of the OneDrive folder.
export TF_DATA_DIR=/tmp/tfdata-s19
# Dummy credentials for the AWS CLI when talking to LocalStack.
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=ap-south-1
cd "$T"

snap 00-localstack-and-files --dir "$S" <<'EOF'
docker ps --filter name=s18-localstack --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
curl -s http://localhost:4566/_localstack/health | jq '{edition, version, ec2: .services.ec2, s3: .services.s3, sts: .services.sts}'
tree -a --noreport .
EOF

snap 01-terraform-init --dir "$S" <<'EOF'
terraform init -no-color
EOF

snap 02-terraform-fmt-validate --dir "$S" <<'EOF'
terraform fmt -check -diff -recursive && echo "fmt: all files already formatted"
terraform validate -no-color
EOF

snap 03-terraform-plan --dir "$S" --max-lines 120 <<'EOF'
terraform plan -no-color -out=tfplan
EOF

snap 04-terraform-apply --dir "$S" --max-lines 80 <<'EOF'
terraform apply -no-color -auto-approve tfplan
EOF

snap 05-terraform-state-list --dir "$S" --max-lines 90 <<'EOF'
terraform state list
terraform state show -no-color aws_instance.web | grep -E '^ +(ami|id|instance_type|instance_state|private_ip|public_ip|subnet_id) +='
terraform state show -no-color aws_vpc.main | grep -E '^ +(id|cidr_block|enable_dns_hostnames) +='
EOF

snap 06-terraform-show --dir "$S" --max-lines 140 <<'EOF'
terraform show -no-color
EOF

snap 07-terraform-output --dir "$S" <<'EOF'
terraform output -no-color
terraform output -raw website_url; echo
EOF

snap 08-verify-vpc-network --dir "$S" --max-lines 100 <<'EOF'
awsl() { aws --endpoint-url=http://localhost:4566 "$@"; }   # LocalStack shortcut
awsl ec2 describe-vpcs --filters Name=tag:Project,Values=s19-vansh --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,Name:Tags[?Key==`Name`]|[0].Value,Owner:Tags[?Key==`Owner`]|[0].Value}' --output table
awsl ec2 describe-subnets --filters Name=vpc-id,Values=$(terraform output -raw vpc_id) --query 'Subnets[].{Subnet:SubnetId,Cidr:CidrBlock,AZ:AvailabilityZone,PublicIP:MapPublicIpOnLaunch}' --output table
awsl ec2 describe-route-tables --filters Name=vpc-id,Values=$(terraform output -raw vpc_id) Name=tag:Name,Values=s19-vansh-public-rt --query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,State]' --output table
awsl ec2 describe-internet-gateways --internet-gateway-ids $(terraform output -raw internet_gateway_id) --query 'InternetGateways[].Attachments[]' --output table
awsl ec2 describe-security-groups --group-ids $(terraform output -raw security_group_id) --query 'SecurityGroups[].IpPermissions[].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp,IpRanges[0].Description]' --output table
EOF

snap 09-verify-ec2-s3 --dir "$S" --max-lines 110 <<'EOF'
awsl() { aws --endpoint-url=http://localhost:4566 "$@"; }   # LocalStack shortcut
awsl ec2 describe-instances --instance-ids $(terraform output -raw instance_id) --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,State:State.Name,AMI:ImageId,Subnet:SubnetId,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value}' --output table
awsl ec2 describe-instance-attribute --instance-id $(terraform output -raw instance_id) --attribute userData --query 'UserData.Value' --output text | base64 -d | grep -E 'nginx|Deployed by'
awsl s3 ls
awsl s3 ls s3://vansh-dobhal-10099-s19-artifacts --recursive
awsl s3 cp s3://$(terraform output -raw artifact_bucket)/$(terraform output -raw user_data_artifact_key) - | grep 'Deployed by'
awsl s3api get-bucket-versioning --bucket vansh-dobhal-10099-s19-artifacts --output text
EOF

snap 10-terraform-graph --dir "$S" <<'EOF'
terraform graph > ../diagrams/terraform-graph.dot && wc -l ../diagrams/terraform-graph.dot
dot -Tpng ../diagrams/terraform-graph.dot -o ../diagrams/terraform-graph.png && ls -la ../diagrams/
grep -E '"aws_instance.web" -> ' ../diagrams/terraform-graph.dot
EOF

snap 11-terraform-plan-no-changes --dir "$S" <<'EOF'
terraform plan -no-color -detailed-exitcode | tail -n 4; echo "exit code: ${PIPESTATUS[0]} (0 = infrastructure matches the configuration)"
EOF

snap 12-terraform-destroy --dir "$S" --max-lines 60 <<'EOF'
terraform destroy -no-color -auto-approve | grep -vE 'Refreshing state|Still destroying'
terraform state list | wc -l
aws --endpoint-url=http://localhost:4566 ec2 describe-instances --filters Name=tag:Project,Values=s19-vansh --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output text
aws --endpoint-url=http://localhost:4566 ec2 describe-vpcs --filters Name=tag:Project,Values=s19-vansh --query 'length(Vpcs)'
aws --endpoint-url=http://localhost:4566 s3 ls | grep -c s19-artifacts || echo "bucket is gone"
EOF
rm -f "$T/tfplan"
