#######
# ECS #
#######
resource "aws_ecs_service" "ut_mongodb_service" {
  name                   = "ut-mongodb-service"
  cluster                = aws_ecs_cluster.ut_cluster.id
  task_definition        = aws_ecs_task_definition.ut_mongodb.arn
  launch_type            = "FARGATE"
  desired_count          = 1
  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.ut_mongodb_target_group.arn
    container_name   = "ut-mongodb"
    container_port   = local.ut_mongodb_container_port
  }

  network_configuration {
    subnets          = var.private_subnets_ids
    security_groups  = [aws_security_group.ut_mongodb_sg.id]
    assign_public_ip = false
  }
}

resource "aws_ecs_task_definition" "ut_mongodb" {
  family       = "ut-mongodb"
  network_mode = "awsvpc"
  cpu          = 256
  memory       = 512

  execution_role_arn       = aws_iam_role.ut_mongodb_container_role.arn
  task_role_arn            = aws_iam_role.ut_mongodb_container_role_task.arn
  requires_compatibilities = ["FARGATE"]

  volume {
    name = "mongodb-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.ut_mongodb_file_system.id
      transit_encryption = "ENABLED"
      authorization_config {
        iam = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name  = "ut-mongodb",
      image = "mongo:8.0-rc-noble",
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.ut_mongodb.name}",
          awslogs-region        = "${var.aws_region}",
          awslogs-stream-prefix = "ecs"
        }
      },
      portMappings = [
        {
          containerPort = "${local.ut_mongodb_container_port}",
          protocol      = "tcp"
        }
      ],
      mountPoints = [
        {
          sourceVolume  = "mongodb-data"
          containerPath = "/data/db"
          readOnly      = false
        }
      ],
      readonlyRootFilesystem = false,
      environment = [
        {
          name  = "MONGO_INITDB_ROOT_USERNAME"
          value = "mongoadmin"
        },
        {
          name  = "MONGO_INITDB_DATABASE"
          value = "ut-db"
        }
      ],
      secrets = [
        {
          name      = "MONGO_INITDB_ROOT_PASSWORD",
          valueFrom = "${aws_secretsmanager_secret.ut_mongodb_password.arn}:MONGODB_PASSWORD::"
        }
      ],
      essential = true
    }
  ])
}


##################
# Security Group #
##################
resource "aws_security_group" "ut_mongodb_sg" {
  name        = "ut-mongodb-sg"
  description = "Controls access to mongodb"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ut_mongodb_nlb_to_mongodb_rule" {
  type        = "ingress"
  from_port   = local.ut_mongodb_container_port
  to_port     = local.ut_mongodb_container_port
  protocol    = "tcp"
  description = "Requests from ut-api containers"

  source_security_group_id = aws_security_group.ut_mongodb_nlb_sg.id
  security_group_id        = aws_security_group.ut_mongodb_sg.id
}

resource "aws_security_group_rule" "ut_mongodb_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  description = "Outbound"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_mongodb_sg.id
}


############
# IAM Role #
############
resource "aws_iam_role" "ut_mongodb_container_role" {
  name = "ut-mongodb-container-exec-role"
  path = "/service-role/fargate/"

  assume_role_policy = data.aws_iam_policy_document.ut_mongodb_role_trust.json
}

resource "aws_iam_role" "ut_mongodb_container_role_task" {
  name = "ut-mongodb-container-task-role"
  path = "/service-role/fargate/"

  assume_role_policy = data.aws_iam_policy_document.ut_mongodb_role_trust.json
}

resource "aws_iam_role_policy" "ut_mongodb_role_policy" {
  name   = "ut-mongodb-container-policy"
  role   = aws_iam_role.ut_mongodb_container_role.id
  policy = data.aws_iam_policy_document.ut_mongodb_role_exec.json
}

resource "aws_iam_role_policy" "ut_mongodb_role_policy_task" {
  name   = "ut-mongodb-container-task-policy"
  role   = aws_iam_role.ut_mongodb_container_role_task.id
  policy = data.aws_iam_policy_document.ut_mongodb_role_exec.json
}

data "aws_iam_policy_document" "ut_mongodb_role_trust" {
  statement {
    sid = "AllowFargate"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values = [
        var.aws_account_id
      ]
    }
  }
}

data "aws_iam_policy_document" "ut_mongodb_role_exec" {
  statement {
    sid = "AllowEcr"

    actions = [
      "ssm:StartSession",
      "ssm:DescribeSessions",
      "ssm:GetSession",
      "ssm:TerminateSession",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid = "AllowEfs"

    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeMountTargets"
    ]

    resources = [
      aws_efs_file_system.ut_mongodb_file_system.arn
    ]
  }

  statement {
    sid = "AllowLogs"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      "*"
    ]
  }
}


###################
# CloudWatch Logs #
###################
resource "aws_cloudwatch_log_group" "ut_mongodb" {
  #checkov:skip=CKV_AWS_158:KMS should be handle by the final customer
  name              = "/ecs/ut-mongodb"
  retention_in_days = 365
}
