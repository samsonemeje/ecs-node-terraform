#!/bin/bash
set -e

echo "ECS Node.js Terraform Bootstrap"
echo "=================================="

# Check if admin profile exists
if ! aws configure list --profile admin >/dev/null 2>&1; then
    echo "Admin profile not found. Run: aws configure --profile admin"
    exit 1
fi

echo "Admin profile found"

# Run bootstrap
echo "🔧 Running bootstrap..."
cd terraform/bootstrap
AWS_PROFILE=admin terraform init
AWS_PROFILE=admin terraform apply -auto-approve

# Get outputs
echo "📋 Getting bootstrap outputs..."
BUCKET_NAME=$(AWS_PROFILE=admin terraform output -raw s3_bucket_name)
ACCESS_KEY=$(AWS_PROFILE=admin terraform output -raw terraform_access_key_id)
SECRET_KEY=$(AWS_PROFILE=admin terraform output -raw terraform_secret_access_key)

echo "Bootstrap complete!"
echo ""
echo "Next steps:"
echo "1. Configure Terraform profile:"
echo "   aws configure --profile terraform"
echo "   Access Key ID: $ACCESS_KEY"
echo "   Secret Access Key: $SECRET_KEY"
echo ""
echo "2. Update backend.tf with bucket: $BUCKET_NAME"
echo ""
echo "3. Run main Terraform:"
echo "   cd ../.. && AWS_PROFILE=terraform terraform init"
echo ""
echo "Store these credentials securely and never commit them!"