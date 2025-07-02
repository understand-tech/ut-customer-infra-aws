#################################
# ----- Global parameters ----- #
#################################

# Replace with your AWS account ID
aws_account_id = ""

# AWS region for deployment
aws_region = ""

# ARN of the IAM role for Terraform deployment
deployment_role_arn = ""

# ARN of the IAM role for administrators
admin_role_arn = ""


###################################
# ----- Network parameters ------ #
###################################

# VPC ID where resources will be deployed
vpc_id = ""

# Private subnet IDs (at least 2 for high availability)
private_subnets_ids = [
]

# Public subnet IDs (at least 2 for high availability)
public_subnets_ids = [
]


#######################################
# ----- UT Frontend Parameters ------ #
#######################################

# Docker image URI for UT Frontend (default provided)
# ut_frontend_registry_uri = "ghcr.io/understand-tech/ut-frontend-customer:1.0.0-release"

# CloudFront SSL certificate ARN (optional)
# cloudfront_acm_certificat_arn = "arn:aws:acm:us-east-1:<your-aws-account-id>:certificate/<certificate-id>"

# CloudFront alternate domains (optional)
# cloudfront_alternate_domain_list = ["your-domain.com", "www.your-domain.com"]


##################################
# ----- UT API Parameters ------ #
##################################

# Docker image URI for UT API (default provided)
# ut_api_registry_uri = "ghcr.io/understand-tech/ut-api-customer:1.0.0-release"


######################################
# ----- UT Workers Parameters ------ #
######################################

# Docker image URI for UT Worker (default provided)
# ut_worker_registry_uri = "ghcr.io/understand-tech/ut-worker-customer:1.0.0-release"


#########################################
# ----- LLM instances Parameters ------ #
#########################################

# Docker image URI for UT LLM (default provided)
# llm_registry_uri = "ghcr.io/understand-tech/ut-llm-customer:1.0.0-release"

# EC2 instance type for LLM instances (GPU-enabled)
# llm_instance_type = "g6.12xlarge"


#################################
# ----- Redis Parameters ------ #
#################################

# Redis node type (adjust based on your performance needs)
# redis_node_type = "cache.r7g.2xlarge"

# Redis backup window (UTC time)
# redis_snapshot_window = "03:00-04:00"

# Redis maintenance window (UTC time, should not overlap with backup)
# redis_maintenance_window = "sun:04:00-sun:05:00"

# Number of backup copies to retain
# redis_backup_retention = 5
