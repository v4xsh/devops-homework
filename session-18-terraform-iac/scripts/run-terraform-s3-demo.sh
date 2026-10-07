#!/usr/bin/env bash
# Runs the full Terraform workflow for terraform-s3-demo against LocalStack
# and captures every step with `snap` (real output -> screenshots/ + outputs/).
set -u
S=~/devops-homework/session-18-terraform-iac/terraform-s3-demo
export PATH="$HOME/.local/bin:$PATH"
# Keep the ~700 MB provider download out of the OneDrive folder.
export TF_DATA_DIR=/tmp/tfdata-s18-s3
# Dummy credentials for the AWS CLI when talking to LocalStack.
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=ap-south-1
cd "$S"

snap 00-localstack-running --dir "$S" <<'EOF'
docker ps --filter name=s18-localstack --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
curl -s http://localhost:4566/_localstack/health | jq '{edition, version, s3: .services.s3, iam: .services.iam, sts: .services.sts}'
terraform version
aws --version
EOF

snap 01-terraform-init --dir "$S" <<'EOF'
ls -la
terraform init -no-color
EOF

snap 02-terraform-fmt-validate --dir "$S" <<'EOF'
terraform fmt -check -diff -recursive && echo "fmt: all files already formatted"
terraform fmt -recursive
terraform validate -no-color
EOF

snap 03-terraform-plan --dir "$S" --max-lines 120 <<'EOF'
terraform plan -no-color -out=tfplan
EOF

snap 04-terraform-apply --dir "$S" --max-lines 90 <<'EOF'
terraform apply -no-color -auto-approve tfplan
EOF

snap 05-terraform-state-show --dir "$S" --max-lines 120 <<'EOF'
terraform state list
terraform state show -no-color aws_s3_bucket.demo
EOF

snap 06-terraform-show --dir "$S" --max-lines 140 <<'EOF'
terraform show -no-color
EOF

snap 07-terraform-output --dir "$S" <<'EOF'
terraform output -no-color
terraform output -raw bucket_name; echo
terraform output -json bucket_tags | jq .
EOF

snap 08-verify-with-aws-cli --dir "$S" --max-lines 90 <<'EOF'
aws --endpoint-url=http://localhost:4566 s3 ls
aws --endpoint-url=http://localhost:4566 s3api get-bucket-versioning --bucket vansh-dobhal-10099-s18-demo
aws --endpoint-url=http://localhost:4566 s3api get-bucket-encryption --bucket vansh-dobhal-10099-s18-demo
aws --endpoint-url=http://localhost:4566 s3api get-public-access-block --bucket vansh-dobhal-10099-s18-demo
aws --endpoint-url=http://localhost:4566 s3api get-bucket-tagging --bucket vansh-dobhal-10099-s18-demo
EOF

snap 09-upload-object-versions --dir "$S" <<'EOF'
echo "version 1 - uploaded by Vansh Dobhal" > hello.txt
aws --endpoint-url=http://localhost:4566 s3 cp hello.txt s3://vansh-dobhal-10099-s18-demo/hello.txt
echo "version 2 - updated by Vansh Dobhal" > hello.txt
aws --endpoint-url=http://localhost:4566 s3 cp hello.txt s3://vansh-dobhal-10099-s18-demo/hello.txt
aws --endpoint-url=http://localhost:4566 s3api list-object-versions --bucket vansh-dobhal-10099-s18-demo --query 'Versions[].{Key:Key,VersionId:VersionId,IsLatest:IsLatest,Size:Size}' --output table
aws --endpoint-url=http://localhost:4566 s3api head-object --bucket vansh-dobhal-10099-s18-demo --key hello.txt --query '{SSE:ServerSideEncryption,VersionId:VersionId}'
rm -f hello.txt
EOF

snap 10-terraform-destroy --dir "$S" --max-lines 90 <<'EOF'
terraform destroy -no-color -auto-approve
terraform state list | wc -l
aws --endpoint-url=http://localhost:4566 s3 ls | grep -c vansh-dobhal-10099-s18-demo || echo "bucket is gone"
EOF
rm -f "$S/tfplan"
