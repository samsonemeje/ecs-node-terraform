environment = "staging"
project_name = "ecs-node"
aws_region = "us-east-1"

# Staging-specific settings
# - Single task
# - 7-day log retention
# - Higher alert thresholds (80% CPU/Memory)
# - Relaxed response time alerts (2s)