###################
# CloudWatch Logs #
###################
resource "aws_cloudwatch_log_group" "ut_api_customer" {
  name              = "/ecs/ut-api-customer"
  retention_in_days = 30
}