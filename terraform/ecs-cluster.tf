#######
# ECS #
#######
resource "aws_ecs_cluster" "ut_cluster" {
  name = "ut-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
