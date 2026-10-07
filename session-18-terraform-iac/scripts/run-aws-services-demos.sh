#!/usr/bin/env bash
# Small AWS CLI demos for the aws-services notes. All run against LocalStack
# (local AWS emulator on http://localhost:4566), NOT a real AWS account.
set -u
A=~/devops-homework/session-18-terraform-iac/aws-services
export PATH="$HOME/.local/bin:$PATH"
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=ap-south-1
awsl() { aws --endpoint-url=http://localhost:4566 "$@"; }

# ---------------------------------------------------------------- IAM
cd "$A/01-iam"
snap 01-iam-users-groups-policies --dir "$A/01-iam" --max-lines 110 <<'EOF'
awsl() { aws --endpoint-url=http://localhost:4566 "$@"; }   # LocalStack shortcut
awsl iam create-group --group-name s18-readers --query 'Group.Arn' --output text
awsl iam create-user --user-name vansh-dev --tags 'Key=Owner,Value=Vansh Dobhal' --query 'User.Arn' --output text
awsl iam add-user-to-group --user-name vansh-dev --group-name s18-readers && echo "vansh-dev added to s18-readers"
awsl iam create-policy --policy-name S3ReadOnlyReportsBucket --policy-document file://policies/s3-read-only-one-bucket.json --query 'Policy.Arn' --output text
awsl iam attach-group-policy --group-name s18-readers --policy-arn arn:aws:iam::000000000000:policy/S3ReadOnlyReportsBucket && echo "policy attached to group"
awsl iam list-attached-group-policies --group-name s18-readers --output table
awsl iam get-group --group-name s18-readers --query 'Users[].UserName' --output text
awsl iam get-policy-version --policy-arn arn:aws:iam::000000000000:policy/S3ReadOnlyReportsBucket --version-id v1 --query 'PolicyVersion.Document.Statement[].[Sid,Action,Resource]' --output table
EOF
snap 02-iam-role-for-ec2 --dir "$A/01-iam" --max-lines 90 <<'EOF'
awsl() { aws --endpoint-url=http://localhost:4566 "$@"; }   # LocalStack shortcut
awsl iam create-role --role-name s18-ec2-app-role --assume-role-policy-document file://policies/ec2-trust-policy.json --query 'Role.[RoleName,Arn]' --output text
awsl iam attach-role-policy --role-name s18-ec2-app-role --policy-arn arn:aws:iam::000000000000:policy/S3ReadOnlyReportsBucket && echo "permission policy attached to role"
awsl iam create-instance-profile --instance-profile-name s18-ec2-app-profile --query 'InstanceProfile.Arn' --output text
awsl iam add-role-to-instance-profile --instance-profile-name s18-ec2-app-profile --role-name s18-ec2-app-role && echo "role added to instance profile"
awsl iam get-role --role-name s18-ec2-app-role --query 'Role.AssumeRolePolicyDocument'
awsl iam list-attached-role-policies --role-name s18-ec2-app-role --output table
EOF
# cleanup IAM demo objects (not captured)
awsl iam remove-role-from-instance-profile --instance-profile-name s18-ec2-app-profile --role-name s18-ec2-app-role
awsl iam delete-instance-profile --instance-profile-name s18-ec2-app-profile
awsl iam detach-role-policy --role-name s18-ec2-app-role --policy-arn arn:aws:iam::000000000000:policy/S3ReadOnlyReportsBucket
awsl iam delete-role --role-name s18-ec2-app-role
awsl iam detach-group-policy --group-name s18-readers --policy-arn arn:aws:iam::000000000000:policy/S3ReadOnlyReportsBucket
awsl iam remove-user-from-group --user-name vansh-dev --group-name s18-readers
awsl iam delete-user --user-name vansh-dev
awsl iam delete-group --group-name s18-readers
awsl iam delete-policy --policy-arn arn:aws:iam::000000000000:policy/S3ReadOnlyReportsBucket

# ---------------------------------------------------------------- EC2
cd "$A/02-ec2"
snap 01-ec2-keypair-sg-instance-lifecycle --dir "$A/02-ec2" --max-lines 110 <<'EOF'
awsl() { aws --endpoint-url=http://localhost:4566 "$@"; }   # LocalStack shortcut
awsl ec2 create-key-pair --key-name s18-vansh-key --query 'KeyName' --output text
awsl ec2 describe-key-pairs --query 'KeyPairs[].[KeyName,KeyFingerprint]' --output table
SG=$(awsl ec2 create-security-group --group-name s18-web-sg --description "web demo" --query GroupId --output text); echo "SG=$SG"
awsl ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 80 --cidr 0.0.0.0/0 --query 'Return'
awsl ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 22 --cidr 203.0.113.10/32 --query 'Return'
awsl ec2 describe-security-groups --group-ids $SG --query 'SecurityGroups[].IpPermissions[].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]' --output table
IID=$(awsl ec2 run-instances --image-id ami-760aaa0f --instance-type t2.micro --key-name s18-vansh-key --security-group-ids $SG --query 'Instances[0].InstanceId' --output text); echo "IID=$IID"
awsl ec2 describe-instances --instance-ids $IID --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,AMI:ImageId,State:State.Name,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,RootDevice:RootDeviceType}' --output table
awsl ec2 stop-instances --instance-ids $IID --query 'StoppingInstances[].[InstanceId,PreviousState.Name,CurrentState.Name]' --output text
awsl ec2 start-instances --instance-ids $IID --query 'StartingInstances[].[InstanceId,PreviousState.Name,CurrentState.Name]' --output text
awsl ec2 terminate-instances --instance-ids $IID --query 'TerminatingInstances[].[InstanceId,PreviousState.Name,CurrentState.Name]' --output text
EOF
awsl ec2 delete-security-group --group-name s18-web-sg
awsl ec2 delete-key-pair --key-name s18-vansh-key

# ---------------------------------------------------------------- S3
cd "$A/03-s3"
snap 01-s3-versioning-lifecycle --dir "$A/03-s3" --max-lines 120 <<'EOF'
awsl() { aws --endpoint-url=http://localhost:4566 "$@"; }   # LocalStack shortcut
awsl s3 mb s3://vansh-dobhal-10099-s3-notes
awsl s3api put-bucket-versioning --bucket vansh-dobhal-10099-s3-notes --versioning-configuration Status=Enabled
awsl s3api get-bucket-versioning --bucket vansh-dobhal-10099-s3-notes
echo "v1" | awsl s3 cp - s3://vansh-dobhal-10099-s3-notes/logs/app.log
echo "v2" | awsl s3 cp - s3://vansh-dobhal-10099-s3-notes/logs/app.log
awsl s3 rm s3://vansh-dobhal-10099-s3-notes/logs/app.log
awsl s3 ls s3://vansh-dobhal-10099-s3-notes/logs/ || echo "(no current object - hidden by a delete marker)"
awsl s3api list-object-versions --bucket vansh-dobhal-10099-s3-notes --query '{Versions:Versions[].[Key,VersionId,IsLatest,Size],DeleteMarkers:DeleteMarkers[].[Key,VersionId,IsLatest]}' --output json
awsl s3api put-bucket-lifecycle-configuration --bucket vansh-dobhal-10099-s3-notes --lifecycle-configuration file://config/lifecycle.json && echo "lifecycle rule saved"
awsl s3api get-bucket-lifecycle-configuration --bucket vansh-dobhal-10099-s3-notes
EOF
# cleanup: delete every version + delete marker, then the bucket
awsl s3api delete-objects --bucket vansh-dobhal-10099-s3-notes --delete "$(awsl s3api list-object-versions --bucket vansh-dobhal-10099-s3-notes --query '{Objects: [Versions, DeleteMarkers][][].{Key:Key,VersionId:VersionId}}' --output json)" > /dev/null
awsl s3 rb s3://vansh-dobhal-10099-s3-notes

# ---------------------------------------------------------------- VPC
cd "$A/04-vpc"
snap 01-vpc-subnets-routing-nacl --dir "$A/04-vpc" --max-lines 120 <<'EOF'
awsl() { aws --endpoint-url=http://localhost:4566 "$@"; }   # LocalStack shortcut
VPC=$(awsl ec2 create-vpc --cidr-block 10.18.0.0/16 --query Vpc.VpcId --output text); echo "VPC=$VPC"
PUB=$(awsl ec2 create-subnet --vpc-id $VPC --cidr-block 10.18.1.0/24 --availability-zone ap-south-1a --query Subnet.SubnetId --output text); echo "public subnet=$PUB"
PRIV=$(awsl ec2 create-subnet --vpc-id $VPC --cidr-block 10.18.2.0/24 --availability-zone ap-south-1b --query Subnet.SubnetId --output text); echo "private subnet=$PRIV"
IGW=$(awsl ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text); echo "IGW=$IGW"
awsl ec2 attach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC && echo "IGW attached to $VPC"
RT=$(awsl ec2 create-route-table --vpc-id $VPC --query RouteTable.RouteTableId --output text); echo "RT=$RT"
awsl ec2 create-route --route-table-id $RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW --query Return
awsl ec2 associate-route-table --route-table-id $RT --subnet-id $PUB --query 'AssociationState.State' --output text
awsl ec2 describe-route-tables --route-table-ids $RT --query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,State]' --output table
awsl ec2 describe-subnets --filters Name=vpc-id,Values=$VPC --query 'Subnets[].[SubnetId,CidrBlock,AvailabilityZone,AvailableIpAddressCount]' --output table
awsl ec2 describe-network-acls --filters Name=vpc-id,Values=$VPC --query 'NetworkAcls[].Entries[].[RuleNumber,Protocol,RuleAction,Egress,CidrBlock]' --output table
echo "$VPC $PUB $PRIV $IGW $RT" > /tmp/s18-vpc-ids
EOF
read VPC PUB PRIV IGW RT < /tmp/s18-vpc-ids
ASSOC=$(awsl ec2 describe-route-tables --route-table-ids $RT --query 'RouteTables[0].Associations[0].RouteTableAssociationId' --output text)
awsl ec2 disassociate-route-table --association-id $ASSOC
awsl ec2 delete-route-table --route-table-id $RT
awsl ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC
awsl ec2 delete-internet-gateway --internet-gateway-id $IGW
awsl ec2 delete-subnet --subnet-id $PUB
awsl ec2 delete-subnet --subnet-id $PRIV
awsl ec2 delete-vpc --vpc-id $VPC

# ---------------------------------------------------------------- DynamoDB / RDS
cd "$A/05-dynamodb-rds"
snap 01-dynamodb-table-items-query --dir "$A/05-dynamodb-rds" --max-lines 120 <<'EOF'
awsl() { aws --endpoint-url=http://localhost:4566 "$@"; }   # LocalStack shortcut
awsl dynamodb create-table --table-name s18-orders --attribute-definitions AttributeName=customer_id,AttributeType=S AttributeName=order_date,AttributeType=S --key-schema AttributeName=customer_id,KeyType=HASH AttributeName=order_date,KeyType=RANGE --billing-mode PAY_PER_REQUEST --query 'TableDescription.[TableName,TableStatus,KeySchema]' --output json
awsl dynamodb wait table-exists --table-name s18-orders && echo "table is ACTIVE"
awsl dynamodb put-item --table-name s18-orders --item '{"customer_id":{"S":"C10099"},"order_date":{"S":"2026-10-01"},"item":{"S":"Keyboard"},"amount":{"N":"2499"}}'
awsl dynamodb put-item --table-name s18-orders --item '{"customer_id":{"S":"C10099"},"order_date":{"S":"2026-10-05"},"item":{"S":"Mouse"},"amount":{"N":"799"},"coupon":{"S":"DIWALI10"}}'
awsl dynamodb put-item --table-name s18-orders --item '{"customer_id":{"S":"C20001"},"order_date":{"S":"2026-10-03"},"item":{"S":"Monitor"},"amount":{"N":"12999"}}'
awsl dynamodb query --table-name s18-orders --key-condition-expression 'customer_id = :c AND order_date >= :d' --expression-attribute-values '{":c":{"S":"C10099"},":d":{"S":"2026-10-02"}}' --output json
awsl dynamodb scan --table-name s18-orders --query 'Items[].[customer_id.S,order_date.S,item.S,amount.N]' --output table
awsl dynamodb delete-table --table-name s18-orders --query 'TableDescription.TableStatus' --output text
EOF
snap 02-rds-not-in-localstack-community --dir "$A/05-dynamodb-rds" <<'EOF'
curl -s http://localhost:4566/_localstack/health | jq '{edition, version, rds_available: (.services | has("rds"))}'
aws --endpoint-url=http://localhost:4566 rds describe-db-instances 2>&1 | tail -n 3
EOF
