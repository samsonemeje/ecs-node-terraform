output "s3_bucket_name" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  description = "DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "terraform_access_key_id" {
  description = "Access key ID for Terraform user"
  value       = aws_iam_access_key.terraform.id
  sensitive   = true
}

output "terraform_secret_access_key" {
  description = "Secret access key for Terraform user"
  value       = aws_iam_access_key.terraform.secret
  sensitive   = true
}