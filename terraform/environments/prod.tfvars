environment = "prod"
project_name = "ecs-node"
aws_region = "us-east-1"

# Production-specific settings
# - 2 tasks or more for high availability
# - 30-day log retention
# - Tight response time alerts (1s)
# - Lower error tolerance (5 5XX errors vs 10)