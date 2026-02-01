#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}

echo " Starting Blue/Green deployment for $ENVIRONMENT environment"

# Get current configuration
ALB_LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $(aws elbv2 describe-load-balancers --names "ecs-node-alb" --query 'LoadBalancers[0].LoadBalancerArn' --output text) --query 'Listeners[0].ListenerArn' --output text --profile terraform)
BLUE_TG_ARN=$(aws elbv2 describe-target-groups --names "ecs-node-$ENVIRONMENT-blue" --query 'TargetGroups[0].TargetGroupArn' --output text --profile terraform)
GREEN_TG_ARN=$(aws elbv2 describe-target-groups --names "ecs-node-$ENVIRONMENT-green" --query 'TargetGroups[0].TargetGroupArn' --output text --profile terraform)
ECR_URL=$(terraform output -raw ecr_repository_url)
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
SERVICE_NAME=$(terraform output -raw ecs_service_name)

echo " Deployment Configuration:"
echo "  Environment: $ENVIRONMENT"
echo "  Image: $ECR_URL:$IMAGE_TAG"
echo "  Blue TG: $BLUE_TG_ARN"
echo "  Green TG: $GREEN_TG_ARN"

# Step 1: Update task definition with new image
echo " Creating new task definition..."
TASK_DEF=$(aws ecs describe-task-definition --task-definition "ecs-node" --query 'taskDefinition' --profile terraform)
NEW_TASK_DEF=$(echo $TASK_DEF | jq --arg IMAGE "$ECR_URL:$IMAGE_TAG" '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)')

# Register new task definition
NEW_REVISION=$(aws ecs register-task-definition --cli-input-json "$NEW_TASK_DEF" --query 'taskDefinition.revision' --output text --profile terraform)
echo " New task definition revision: $NEW_REVISION"

# Step 2: Update service to use green target group
echo " Switching to green environment..."
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --task-definition "ecs-node:$NEW_REVISION" \
  --load-balancers targetGroupArn="$GREEN_TG_ARN",containerName="ecs-node",containerPort=3000 \
  --profile terraform

# Step 3: Wait for service to stabilize
echo " Waiting for service to stabilize..."
aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --profile terraform

# Step 4: Check green target group health
echo " Checking green target group health..."
for i in {1..10}; do
  HEALTHY_COUNT=$(aws elbv2 describe-target-health --target-group-arn "$GREEN_TG_ARN" --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text --profile terraform)
  if [ "$HEALTHY_COUNT" -gt 0 ]; then
    echo " Green environment is healthy ($HEALTHY_COUNT targets)"
    break
  fi
  echo " Waiting for green targets to become healthy... ($i/10)"
  sleep 30
done

# Step 5: Switch ALB traffic to green
echo " Switching ALB traffic to green..."
aws elbv2 modify-listener \
  --listener-arn "$ALB_LISTENER_ARN" \
  --default-actions Type=forward,TargetGroupArn="$GREEN_TG_ARN" \
  --profile terraform

echo " Blue/Green deployment completed!"
echo " Blue (old): $BLUE_TG_ARN"
echo " Green (new): $GREEN_TG_ARN"
echo " Traffic now pointing to: Green"
echo ""
echo "To rollback, run:"
echo "aws elbv2 modify-listener --listener-arn $ALB_LISTENER_ARN --default-actions Type=forward,TargetGroupArn=$BLUE_TG_ARN --profile terraform"