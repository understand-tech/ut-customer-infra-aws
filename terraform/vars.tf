#################################
# ----- Global parameters ----- #
#################################
variable "aws_account_id" {
  description = "ID of the AWS account used to host the UT-APP"
  type        = string
}

variable "aws_region" {
  description = "AWS region to use for deployment"
  type        = string
}

variable "deployment_role_arn" {
  description = "ARN of the IAM role that should be used by Terraform for deployment"
  type        = string
}

variable "admin_role_arn" {
  description = "ARN of the IAM role used by administrators"
  type        = string
}


###################################
# ----- Network parameters ------ #
###################################
variable "vpc_id" {
  description = "ID of the VPC to use"
  type        = string
}

variable "private_subnets_ids" {
  description = "IDs of the private subnets to use"
  type        = list(string)
}

variable "public_subnets_ids" {
  description = "IDs of the private subnets to use"
  type        = list(string)
}


#######################################
# ----- UT Frontend Parameters ------ #
#######################################
variable "ut_frontend_registry_uri" {
  description = "URI used to download UT Frontend docker image"
  default     = "ghcr.io/understand-tech/ut-frontend-customer:1.0.1-release"
  type        = string
}

variable "cloudfront_acm_certificat_arn" {
  description = "ACM certificat arn to use for cloudfront distribution"
  type        = string
  default     = ""
}

variable "cloudfront_alternate_domain_list" {
  description = "List of the cloudfront distribution alternate domains"
  type        = list(string)
  default     = []
}


##################################
# ----- UT API Parameters ------ #
##################################
variable "ut_api_registry_uri" {
  description = "URI used to download UT API docker image"
  default     = "ghcr.io/understand-tech/ut-api-customer:1.0.1-release"
  type        = string
}


######################################
# ----- UT Workers Parameters ------ #
######################################
variable "ut_worker_registry_uri" {
  description = "URI used to download UT Worker docker image"
  default     = "ghcr.io/understand-tech/ut-worker-customer:1.0.1-release"
  type        = string
}


#########################################
# ----- LLM instances Parameters ------ #
#########################################
variable "llm_registry_uri" {
  description = "URI used to download UT LLM docker image"
  default     = "ghcr.io/understand-tech/ut-llm-customer:1.0.1-release"
  type        = string
}

variable "llm_instance_type" {
  description = "EC2 instance type to use for LLM instances"
  default     = "g6e.8xlarge"
  type        = string
}


#################################
# ----- Redis Parameters ------ #
#################################
variable "redis_node_type" {
  description = "Define the size of the redis instances"
  default     = "cache.t4g.small"
  type        = string
}

variable "redis_snapshot_window" {
  description = "Define the time interval when AWS will proceed to cluster backup"
  default     = "03:00-04:00"
  type        = string
}
# UTC Time
# Snapshot and maintenance window should not overlap

variable "redis_maintenance_window" {
  description = "Define the time interval when AWS will proceed to cluster maintenance"
  default     = "sun:04:00-sun:05:00"
  type        = string
}
# UTC Time

variable "redis_backup_retention" {
  description = "Define the number of backup copy to keep"
  default     = 5
  type        = number
}
