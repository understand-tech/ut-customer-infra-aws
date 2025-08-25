###################
# CloudWatch Logs #
###################
resource "aws_cloudwatch_log_group" "ut_api_customer" {
  #checkov:skip=CKV_AWS_158:KMS should be handle by the final customer
  name              = "/ecs/ut-api-customer"
  retention_in_days = 365
}