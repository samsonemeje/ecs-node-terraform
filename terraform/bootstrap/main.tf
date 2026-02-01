# Bootstrap - Run ONCE with admin credentials
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "ecs-node-terraform-state-${random_id.bucket_suffix.hex}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# Terraform IAM policy
resource "aws_iam_policy" "terraform" {
  name        = "terraform-ecs-platform-policy"
  description = "Least privilege policy for Terraform ECS provisioning"
  policy      = file("${path.module}/../policies/terraform-policy.json")
}

# Terraform IAM user
resource "aws_iam_user" "terraform" {
  name = "terraform-ecs-user"
  path = "/automation/"
}

resource "aws_iam_user_policy_attachment" "terraform_attach" {
  user       = aws_iam_user.terraform.name
  policy_arn = aws_iam_policy.terraform.arn
}

# Access keys (output once, store securely)
resource "aws_iam_access_key" "terraform" {
  user = aws_iam_user.terraform.name
}