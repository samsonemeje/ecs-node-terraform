# Production-Ready ECS Node.js Deployment

A secure, scalable Node.js backend deployment on AWS ECS with least-privilege IAM, OIDC CI/CD, Blue/Green deployments, and comprehensive monitoring.

## Project Overview

This project demonstrates enterprise-grade DevOps practices by implementing:
- **Zero-downtime deployments** using Blue/Green strategy
- **Comprehensive monitoring** with environment-specific alerting
- **Security-first approach** with least-privilege IAM and OIDC authentication
- **Environment parity** across dev/staging/production
- **Infrastructure as Code** with Terraform state management

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Account                            │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    VPC (10.0.0.0/16)                       ││
│  │                                                             ││
│  │  ┌─────────────────┐    ┌─────────────────┐                ││
│  │  │  Public Subnet  │    │  Public Subnet  │                ││
│  │  │   10.0.1.0/24   │    │   10.0.2.0/24   │                ││
│  │  │      AZ-1       │    │      AZ-2       │                ││
│  │  └─────────────────┘    └─────────────────┘                ││
│  │           │                       │                        ││
│  │  ┌─────────────────────────────────────────┐               ││
│  │  │        Application Load Balancer        │               ││
│  │  │              (Port 80)                  │               ││
│  │  └─────────────────────────────────────────┘               ││
│  │                       │                                    ││
│  │  ┌─────────────────────────────────────────┐               ││
│  │  │            ECS Fargate Service          │               ││
│  │  │         (Node.js App - Port 3000)      │               ││
│  │  │                                         │               ││
│  │  │  ┌─────────────┐  ┌─────────────┐     │               ││
│  │  │  │    Task 1   │  │    Task N   │     │               ││
│  │  │  │             │  │             │     │               ││
│  │  │  └─────────────┘  └─────────────┘     │               ││
│  │  └─────────────────────────────────────────┘               ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │       ECR       │  │   CloudWatch    │  │    DynamoDB     │ │
│  │   (Container    │  │     Logs        │  │  (Terraform     │ │
│  │    Registry)    │  │                 │  │    Locks)       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    S3 Bucket                                ││
│  │               (Terraform State)                             ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Security Architecture

### IAM Privilege Separation
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Admin User    │───▶│ Terraform User  │───▶│   CI/CD Role    │
│  (Bootstrap)    │    │ (Infrastructure)│    │  (Deployments)  │
│                 │    │                 │    │                 │
│ • Full Access   │    │ • ECS/VPC/ALB   │    │ • ECS Deploy    │
│ • Used Once     │    │ • ECR/Logs      │    │ • ECR Access    │
│ • Locked Away   │    │ • IAM (ecs-*)   │    │ • OIDC Only     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

**Decision Rationale**: Three-tier IAM separation ensures admin credentials are only used for initial bootstrap, operational access is scoped to specific services, and CI/CD uses temporary tokens without long-lived secrets.

## Blue/Green Deployment Strategy

### Architecture Flow
```
ALB → Blue Target Group (Production)
    ↓ (Deploy to Green)
ALB → Blue TG (Old) + Green TG (New, being tested)
    ↓ (Switch Traffic)
ALB → Green Target Group (New Production)
```

**Benefits**:
- **Zero Downtime**: Instant traffic switching
- **Manual Control**: Full control over traffic switching
- **Production Testing**: Validate green environment before switching
- **Quick Recovery**: Immediate rollback capability

**Decision Log**: Chose manual ALB listener switching over AWS CodeDeploy due to:
1. **Cost**: No additional CodeDeploy charges
2. **Control**: Manual validation before traffic switch
3. **Simplicity**: Direct ALB API calls vs CodeDeploy complexity
4. **Reliability**: Proven ALB target group switching mechanism

## Monitoring & Alerting

### CloudWatch Dashboard
Environment-specific dashboards with:
- **ECS Metrics**: CPU and Memory utilization
- **ALB Metrics**: Request count, response time, HTTP status codes
- **Real-time Monitoring**: 5-minute intervals with historical data

### Environment-Specific Alerting

| Metric | Development | Production | Rationale |
|--------|-------------|------------|-----------|
| **CPU Utilization** | 80% | 70% | Tighter prod monitoring |
| **Memory Utilization** | 80% | 70% | Earlier prod intervention |
| **Response Time** | 2 seconds | 1 second | Stricter prod SLA |
| **5XX Errors** | 10 errors | 5 errors | Lower prod error tolerance |

**Decision Log**: Environment-specific thresholds reflect different operational requirements:
- **Development**: Higher thresholds for cost optimization and testing flexibility
- **Production**: Lower thresholds for proactive issue detection and user experience

## Environment Parity

### Configuration Matrix

| Feature | Development | Staging | Production |
|---------|-------------|---------|------------|
| **Tasks** | 1 | 1 | 2 |
| **Log Retention** | 7 days | 7 days | 30 days |
| **Termination Wait** | 1 min | 1 min | 5 min |

**Decision Rationale**:
- **Task Count**: Single task for dev/staging reduces costs; dual tasks for prod ensures availability
- **Log Retention**: Shorter retention for non-prod reduces storage costs
- **Termination Wait**: Longer prod wait time allows graceful connection draining

## Technology Decisions

### Why AWS Fargate?
- **Serverless**: No EC2 instance management overhead
- **Auto-scaling**: Container-level scaling based on demand
- **Security**: Isolated compute environment per task
- **Cost-effective**: Pay only for running tasks, no idle capacity

### Why Application Load Balancer?
- **HTTP/HTTPS**: Layer 7 routing capabilities for web applications
- **Health Checks**: Automatic unhealthy target removal
- **Multi-AZ**: High availability across availability zones
- **ECS Integration**: Native service discovery and target registration

### Why Terraform State in S3?
- **Collaboration**: Shared state for team access
- **Durability**: 99.999999999% (11 9's) durability
- **Versioning**: State history and rollback capability
- **Encryption**: Data protection at rest and in transit

## Deployment Guide

### Prerequisites
- AWS CLI configured with admin credentials (bootstrap only)
- Terraform >= 1.5.0
- Docker (for container builds)

### Phase 1: Bootstrap (One-time Admin Setup)

**⚠️ CRITICAL: This step uses admin credentials and is only run ONCE**

```bash
# Configure admin profile
aws configure --profile admin

# Run automated bootstrap
./scripts/bootstrap.sh
```

**What this creates**:
- S3 bucket for Terraform state (encrypted)
- DynamoDB table for state locking
- Scoped Terraform IAM user with minimal permissions
- IAM policies following least privilege principle

### Phase 2: Infrastructure Deployment

```bash
# Configure Terraform user profile
aws configure --profile terraform
# Use Access Key ID and Secret from bootstrap output

# Update backend configuration
# Edit terraform/backend.tf with S3 bucket name from bootstrap

# Deploy infrastructure
cd terraform
export AWS_PROFILE=terraform
terraform init
```

### Multi-Environment Deployment

**Deploy to Development:**
```bash
terraform apply -var-file="environments/dev.tfvars"
```

**Deploy to Staging:**
```bash
terraform apply -var-file="environments/staging.tfvars"
```

**Deploy to Production:**
```bash
terraform apply -var-file="environments/prod.tfvars"
```

### Environment Configuration Files

**`environments/dev.tfvars`:**

**`environments/staging.tfvars`:**

**`environments/prod.tfvars`:**


### Environment Isolation

Each environment creates isolated resources:
- **Separate VPCs**: `vpc-dev`, `vpc-staging`, `vpc-prod`
- **Separate ECS Clusters**: `ecs-node-cluster-dev`, `ecs-node-cluster-prod`
- **Separate ALBs**: `ecs-node-alb-dev`, `ecs-node-alb-prod`
- **Environment-specific naming**: All resources tagged with environment

### Promotion Workflow

```bash
# 1. Test in development
terraform apply -var-file="environments/dev.tfvars"
# Deploy app and validate

# 2. Promote to staging
terraform apply -var-file="environments/staging.tfvars"
# Run integration tests

# 3. Deploy to production
terraform apply -var-file="environments/prod.tfvars"
# Monitor and validate
```

### Phase 3: CI/CD Setup (OIDC Authentication)

**⚠️ PREREQUISITE: Complete Phase 1 and Phase 2 first**

#### Step 1: Update Terraform User Permissions
```bash
# Update terraform user policy to include OIDC permissions
cd terraform/bootstrap
export AWS_PROFILE=admin
terraform apply
```

#### Step 2: Deploy OIDC Provider and GitHub Actions Role
```bash
cd ../iam

# Configure GitHub repository (replace with your username/repo)
echo 'github_repo = "yourusername/yourrepo"' > terraform.tfvars

# Deploy OIDC resources
export AWS_PROFILE=terraform
terraform init
terraform apply
```

#### Step 3: Configure GitHub Repository Secrets
```bash
# Get your AWS Account ID
aws sts get-caller-identity --query Account --output text
```

**Add GitHub Repository Secret:**
1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `AWS_ACCOUNT_ID`
5. Value: Your AWS Account ID from the command above

#### Step 4: Test CI/CD Pipeline
```bash
# Push changes to trigger GitHub Actions
git add .
git commit -m "Setup OIDC CI/CD pipeline"
git push origin main
```

**What this creates:**
- GitHub OIDC provider in AWS
- IAM role for GitHub Actions with minimal ECS deployment permissions
- Secure CI/CD pipeline without long-lived AWS credentials

### Phase 4: Application Deployment

**Manual Deployment (Alternative to CI/CD):**

```bash
cd app

# Login to ECR
aws ecr get-login-password --region us-east-1 --profile terraform | \
  docker login --username AWS --password-stdin <ECR_URL>

# Build for Fargate (linux/amd64)
docker build --platform linux/amd64 -t ecs-node .
docker tag ecs-node:latest <ECR_URL>:latest
docker push <ECR_URL>:latest

# Deploy to ECS
aws ecs update-service \
  --cluster ecs-node-cluster \
  --service ecs-node-dev \
  --force-new-deployment \
  --region us-east-1 \
  --profile terraform
```

## Monitoring Access

### CloudWatch Dashboard
```bash
# Get dashboard URL
terraform output cloudwatch_dashboard_url

# Open in browser
open "$(terraform output -raw cloudwatch_dashboard_url)"
```

### CLI Monitoring
```bash
# View application logs
aws logs tail /ecs/ecs-node-dev --follow --region us-east-1 --profile terraform

# Check service status
aws ecs describe-services --cluster ecs-node-cluster --service ecs-node-dev --region us-east-1 --profile terraform

# Check alarms
aws cloudwatch describe-alarms --alarm-names ecs-node-dev-high-cpu --region us-east-1 --profile terraform
```

## Blue/Green Deployment Process

### Manual Deployment Steps
```bash
# 1. Deploy new version to green target group
aws ecs update-service \
  --cluster ecs-node-cluster \
  --service ecs-node-dev \
  --force-new-deployment \
  --region us-east-1 \
  --profile terraform

# 2. Verify green target group health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --names ecs-node-dev-green --query 'TargetGroups[0].TargetGroupArn' --output text) \
  --region us-east-1 \
  --profile terraform

# 3. Switch traffic to green (manual decision point)
aws elbv2 modify-listener \
  --listener-arn <LISTENER_ARN> \
  --default-actions Type=forward,TargetGroupArn=<GREEN_TG_ARN> \
  --region us-east-1 \
  --profile terraform

# 4. Rollback if needed (switch back to blue)
aws elbv2 modify-listener \
  --listener-arn <LISTENER_ARN> \
  --default-actions Type=forward,TargetGroupArn=<BLUE_TG_ARN> \
  --region us-east-1 \
  --profile terraform
```

## Project Structure

```
devops-task/
├── terraform/
│   ├── main.tf                    # Core ECS infrastructure with Blue/Green
│   ├── variables.tf               # Input variables with environment support
│   ├── outputs.tf                 # Resource outputs including URLs and ARNs
│   ├── providers.tf               # AWS provider configuration
│   ├── backend.tf                 # S3 backend configuration
│   ├── environments/              # Environment-specific configurations
│   │   ├── dev.tfvars            # Development environment
│   │   ├── staging.tfvars        # Staging environment
│   │   └── prod.tfvars           # Production environment
│   ├── bootstrap/                 # One-time admin setup
│   │   ├── main.tf               # Bootstrap resources
│   │   ├── variables.tf          # Bootstrap variables
│   │   └── outputs.tf            # Bootstrap outputs
│   ├── iam/                      # CI/CD roles and policies
│   │   ├── cicd-role.tf          # GitHub Actions OIDC role
│   │   └── variables.tf          # GitHub repo configuration
│   └── policies/                 # JSON policy documents
│       ├── terraform-policy.json # Scoped Terraform permissions
│       └── cicd-policy.json      # Minimal deployment permissions
├── app/
│   ├── src/
│   │   └── index.js              # Express.js server
│   ├── Dockerfile                # Container definition
│   ├── package.json              # Node.js dependencies
│   └── .dockerignore             # Docker build exclusions
├── scripts/
│   ├── bootstrap.sh              # Automated setup script
│   ├── validate-policies.sh      # IAM policy validation
│   └── terraform-safety-check.sh # Terraform safety checks
└── README.md                     # This documentation
```

## Troubleshooting

### Common Issues

**503 Service Unavailable**
- Check ECS service status and task health
- Verify Docker image exists in ECR
- Ensure health check endpoint responds correctly

**Tasks Stuck in PENDING**
- Check ECS service events for detailed errors
- Verify network configuration (subnets, security groups)
- Ensure ECR connectivity (public IP assignment)

**Docker Platform Issues**
- Build with `--platform linux/amd64` for Fargate compatibility
- Verify image architecture matches ECS requirements

### Diagnostic Commands
```bash
# Check ECS service events
aws ecs describe-services --cluster ecs-node-cluster --service ecs-node-dev --region us-east-1 --profile terraform --query 'services[0].events[0:5]'

# Check target group health
aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN> --region us-east-1 --profile terraform

# View detailed logs
aws logs tail /ecs/ecs-node-dev --follow --region us-east-1 --profile terraform
```

## Production Enhancements

### Immediate Improvements
- **HTTPS/TLS**: SSL termination at ALB with ACM certificates
- **Private Subnets**: Move ECS tasks to private subnets with NAT Gateway
- **Auto Scaling**: ECS Service Auto Scaling based on CPU/memory metrics
- **Secrets Manager**: Secure storage for database credentials and API keys

### Advanced Features
- **WAF**: Web Application Firewall for DDoS protection
- **VPC Endpoints**: Private connectivity to AWS services
- **Multi-Region**: Cross-region deployment for disaster recovery
- **Container Insights**: Enhanced ECS monitoring and logging

## Key Metrics

After successful deployment:

```bash
alb_dns_name                    = "ecs-node-alb-1379496322.us-east-1.elb.amazonaws.com"
alb_url                        = "http://ecs-node-alb-1379496322.us-east-1.elb.amazonaws.com"
ecr_repository_url             = "577638372084.dkr.ecr.us-east-1.amazonaws.com/ecs-node"
ecs_cluster_name               = "ecs-node-cluster"
ecs_service_name               = "ecs-node-dev"
blue_target_group_name         = "ecs-node-dev-blue"
green_target_group_name        = "ecs-node-dev-green"
cloudwatch_dashboard_url       = "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=ecs-node-dev-dashboard"
sns_topic_arn                  = "arn:aws:sns:us-east-1:577638372084:ecs-node-dev-alerts"
environment                    = "dev"
vpc_id                        = "vpc-0473e956ad41dbb10"
```

## Success Criteria

This project successfully demonstrates:

**Advanced Deployment Strategy**: Blue/Green deployment with manual traffic switching
**Comprehensive Monitoring**: Environment-specific CloudWatch dashboards and alerting
**Environment Parity**: Consistent infrastructure across dev/staging/production
**Security Best Practices**: Least-privilege IAM with OIDC authentication
**Infrastructure as Code**: Fully automated Terraform deployment
**Production Readiness**: Scalable, monitored, and maintainable architecture

## Post-Assessment Analysis

###  Conscious Trade-offs Due to Time Constraints

**1. Public Subnets for ECS Tasks**
- **Trade-off**: Used public subnets instead of private subnets with NAT Gateway
- **Reason**: Faster deployment, no NAT Gateway costs during development
- **Production Impact**: Increased security risk, direct internet access

**2. Manual Blue/Green Switching**
- **Trade-off**: Manual ALB listener switching vs automated CodeDeploy
- **Reason**: Simpler implementation, no additional AWS service complexity
- **Production Impact**: Human error risk, slower deployment process

**3. No Database Layer**
- **Trade-off**: Stateless application vs persistent data storage
- **Reason**: Focus on infrastructure deployment patterns
- **Production Impact**: Cannot store user data or application state

**4. Basic Monitoring**
- **Trade-off**: CloudWatch dashboards vs comprehensive observability (X-Ray, Container Insights)
- **Reason**: Core monitoring functionality without advanced setup
- **Production Impact**: Limited debugging and performance analysis capabilities

**5. Single Region Deployment**
- **Trade-off**: Single region vs multi-region with failover
- **Reason**: Reduced complexity and faster initial deployment
- **Production Impact**: Single point of failure, no disaster recovery

### What would i change if this were running in production for 1 million users?

**1. Auto Scaling & Load Distribution**
```hcl
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 50
  min_capacity       = 5
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
```

**2. Multi-Region Deployment with Route 53 Failover**
- Deploy identical infrastructure in us-west-2
- Route 53 health checks with automatic failover
- Cross-region RDS read replicas

**3. Database Layer with Persistence**
```hcl
resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.project_name}-${var.environment}"
  engine            = "aurora-mysql"
  engine_mode       = "serverless"
  
  scaling_configuration {
    max_capacity = 256
    min_capacity = 2
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project_name}-cache"
  node_type           = "cache.r6g.large"
  num_cache_clusters  = 2
}
```

**4. CDN with CloudFront & WAF Protection**
```hcl
resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "ALB-${var.project_name}"
  }
  
  web_acl_id = aws_wafv2_web_acl.main.arn
}

resource "aws_wafv2_web_acl" "main" {
  rule {
    name = "RateLimitRule"
    statement {
      rate_based_statement {
        limit = 2000  # requests per 5 minutes
      }
    }
  }
}
```

**5. Enhanced Observability**
- X-Ray distributed tracing
- Container Insights for ECS
- Custom business metrics
- Structured logging with correlation IDs

### Where are the biggest risks in my current setup?

**1. Single Point of Failure**
- **Risk**: Single region deployment (us-east-1)
- **Impact**: Complete outage if region fails
- **Mitigation**: Multi-region deployment with Route 53 failover

**2. No Data Persistence**
- **Risk**: Stateless application with no database
- **Impact**: Cannot store user data, sessions, or application state
- **Mitigation**: Add RDS Aurora + Redis for caching

**3. Public Subnets for ECS Tasks**
- **Risk**: ECS tasks have direct internet access
- **Impact**: Increased attack surface, potential data exfiltration
- **Mitigation**: Move to private subnets with NAT Gateway

**4. No WAF Protection**
- **Risk**: Direct ALB exposure to internet
- **Impact**: Vulnerable to DDoS, SQL injection, XSS attacks
- **Mitigation**: CloudFront + WAF with rate limiting

**5. Manual Blue/Green Switching**
- **Risk**: Human error during traffic switching
- **Impact**: Potential downtime or routing to unhealthy targets
- **Mitigation**: Automated health checks before switching

**6. SNS Alerts Without Subscribers**
- **Risk**: CloudWatch alarms trigger but no notifications sent
- **Impact**: Undetected outages and performance issues
- **Mitigation**: Configure email/Slack subscriptions

