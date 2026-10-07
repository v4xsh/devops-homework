#!/usr/bin/env bash
# Final project - Terraform: fmt/validate, full plan (VPC + EKS + ECR + S3), real apply/destroy against LocalStack.
# Terraform runs in ~/build/s21-tf so .terraform/ and state never land in the repo.
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
cd "$P"
LS_PORT=4596
export TF_IN_AUTOMATION=1
export PATH="$HOME/venv-s21/bin:$PATH"   # aws CLI (pip awscli) lives in this venv
rm -rf ~/build/s21-tf && mkdir -p ~/build/s21-tf && cp terraform/*.tf terraform/*.tfvars* ~/build/s21-tf/

docker rm -f s21-localstack >/dev/null 2>&1
docker run -d --name s21-localstack -p 127.0.0.1:${LS_PORT}:4566 -e SERVICES=ec2,s3,iam,sts,kms localstack/localstack:4.9 >/dev/null
until curl -s localhost:${LS_PORT}/_localstack/health | grep -q '"ec2"'; do sleep 3; done

snap 21-terraform-fmt-validate --dir "$P" <<'EOF'
cd ~/build/s21-tf && terraform version | head -n 2
terraform fmt -check -recursive -diff && echo "terraform fmt: OK (no changes needed)"
terraform init -backend=false -input=false -no-color | grep -E 'Installing|Installed|initialized'
terraform validate -no-color
ls *.tf
EOF

snap 22-terraform-plan-full --dir "$P" --max-lines 90 <<'EOF'
cd ~/build/s21-tf
terraform plan -input=false -no-color -var use_localstack=true -var localstack_endpoint=http://localhost:4596 -out full.tfplan > plan-full.txt; echo "plan exit code: $?"
grep -E '^  # ' plan-full.txt | sed 's/ will be created//' | sort | head -n 60
grep -E '^Plan:' plan-full.txt
terraform show -json full.tfplan | jq -r '.resource_changes[] | select(.type=="aws_eks_cluster" or .type=="aws_eks_node_group") | "\(.address): \(.change.after | {name, version, instance_types, scaling_config} | tostring)"' | cut -c1-200
EOF

snap 23-terraform-apply-localstack --dir "$P" --max-lines 90 <<'EOF'
cd ~/build/s21-tf && grep -vE '^\s*#' localstack.tfvars
docker ps --filter name=s21-localstack --format '{{.Names}} {{.Image}} {{.Status}}'
terraform apply -input=false -no-color -auto-approve -var-file=localstack.tfvars -var localstack_endpoint=http://localhost:4596 | grep -E 'Creation complete|Apply complete|Error' | sed 's/\[id=.*\]//' | sort | uniq | head -n 40
terraform output -no-color
terraform state list | wc -l
EOF

snap 24-terraform-verify-destroy --dir "$P" <<'EOF'
cd ~/build/s21-tf
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url http://localhost:4596 --region us-east-1 ec2 describe-subnets --filters Name=vpc-id,Values=$(terraform output -raw vpc_id) --query 'Subnets[].[CidrBlock,AvailabilityZone,Tags[?Key==`Name`]|[0].Value]' --output text
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url http://localhost:4596 --region us-east-1 s3api get-bucket-versioning --bucket vansh-10099-taskboard-artifacts
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url http://localhost:4596 --region us-east-1 s3api get-bucket-encryption --bucket vansh-10099-taskboard-artifacts --query "ServerSideEncryptionConfiguration.Rules[0]"
terraform destroy -input=false -no-color -auto-approve -var-file=localstack.tfvars -var localstack_endpoint=http://localhost:4596 | grep -E 'Destroy complete|Error'
terraform state list | wc -l
EOF

docker rm -f s21-localstack >/dev/null
# keep the provider lock file in the repo (pins provider hashes for CI)
cp ~/build/s21-tf/.terraform.lock.hcl "$P/terraform/"
