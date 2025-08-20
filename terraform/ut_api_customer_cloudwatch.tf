###################
# CloudWatch Logs #
###################
resource "aws_cloudwatch_log_group" "ut_api_customer" {
  name              = "/ecs/ut-api-customer"
  retention_in_days = 30
}

#####################
# CloudWatch Alarms #
#####################
resource "aws_cloudwatch_metric_alarm" "ut_api_customer_task_count_alarm" {
  alarm_name        = "UT-API-CUSTOMER - Task count above 0"
  alarm_description = "The number of ECS task for UT-API-CUSTOMER is below to 1"
  alarm_actions     = [module.notify_slack.this_slack_topic_arn]
  ok_actions        = [module.notify_slack.this_slack_topic_arn]

  metric_name = "RunningTaskCount"
  namespace   = "ECS/ContainerInsights"

  dimensions = {
    ServiceName = aws_ecs_service.ut_api_customer_service.name
    ClusterName = aws_ecs_cluster.ecs_cluster.name
  }

  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
}

resource "aws_cloudwatch_metric_alarm" "ut_api_customer_cpu_alarm" {
  alarm_name        = "UT-API-CUSTOMER - CPU above 80"
  alarm_description = "In average, ECS tasks for UT-API-CUSTOMER CPU is above to 80 pourcent"
  alarm_actions     = [module.notify_slack.this_slack_topic_arn]
  ok_actions        = [module.notify_slack.this_slack_topic_arn]

  metric_name = "CPUUtilization"
  namespace   = "AWS/ECS"

  dimensions = {
    ServiceName = aws_ecs_service.ut_api_customer_service.name
    ClusterName = aws_ecs_cluster.ecs_cluster.name
  }

  statistic           = "Average"
  period              = 60
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
}

resource "aws_cloudwatch_metric_alarm" "ut_api_customer_memory_alarm" {
  alarm_name        = "UT-API-CUSTOMER - RAM above 80"
  alarm_description = "In average, ECS tasks RAM usage for UT-API-CUSTOMER is above to 80 pourcent"
  alarm_actions     = [module.notify_slack.this_slack_topic_arn]
  ok_actions        = [module.notify_slack.this_slack_topic_arn]

  metric_name = "MemoryUtilization"
  namespace   = "AWS/ECS"

  dimensions = {
    ServiceName = aws_ecs_service.ut_api_customer_service.name
    ClusterName = aws_ecs_cluster.ecs_cluster.name
  }

  statistic           = "Average"
  period              = 60
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
}
