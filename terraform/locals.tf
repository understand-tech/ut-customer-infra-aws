locals {
  ut_frontend_container_port = 80
  ut_api_container_port      = 8501
  ut_redis_port              = 6379
  ut_llm_container_port      = 8000
  ut_llm_elb_port            = 80
  ut_mongodb_container_port  = 27017
  ut_efs_port                = 2049
  
  # Use custom domain if provided, otherwise use CloudFront distribution domain
  frontend_domain = length(var.cloudfront_alternate_domain_list) > 0 ? var.cloudfront_alternate_domain_list[0] : aws_cloudfront_distribution.ut_frontend_distribution.domain_name
}