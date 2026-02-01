#!/bin/bash
set -e

echo " Running IAM policy validation..."

# Validate Terraform policy
echo "Validating Terraform policy..."
aws accessanalyzer validate-policy \
  --policy-document file://terraform/policies/terraform-policy.json \
  --policy-type IDENTITY_POLICY \
  --output table

# Validate CI/CD policy
echo "Validating CI/CD policy..."
aws accessanalyzer validate-policy \
  --policy-document file://terraform/policies/cicd-policy.json \
  --policy-type IDENTITY_POLICY \
  --output table

echo " Policy validation complete"