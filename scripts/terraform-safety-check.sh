#!/bin/bash
set -e

echo " Running Terraform safety checks..."

# Generate plan
terraform plan -out=tfplan

# Check for dangerous operations
echo "Checking for dangerous operations..."
terraform show -json tfplan | jq -r '
  .resource_changes[] | 
  select(.change.actions[] | contains("delete")) |
  " DELETE: \(.address) - \(.change.actions | join(","))"
'

# Check for IAM privilege escalation
echo "Checking for IAM privilege escalation..."
terraform show -json tfplan | jq -r '
  .resource_changes[] |
  select(.type == "aws_iam_policy" and (.change.actions[] | contains("create") or contains("update"))) |
  select(.change.after.policy | contains("*")) |
  " WILDCARD DETECTED: \(.address)"
'

echo " Safety checks complete"