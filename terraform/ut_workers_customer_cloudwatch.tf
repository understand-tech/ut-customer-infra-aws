###################
# CloudWatch Logs #
###################
resource "aws_cloudwatch_log_group" "workers_customer" {
  name              = "/ecs/workers-customer"
  retention_in_days = 30
}