#######
# ECS #
#######
resource "aws_ecs_service" "ut_api_customer_service" {
  name                   = "ut-api-customer-service"
  cluster                = aws_ecs_cluster.ecs_cluster.id
  task_definition        = aws_ecs_task_definition.ut_api_customer.arn
  launch_type            = "FARGATE"
  desired_count          = var.ut_api_customer_desired_count
  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.ut_api_custom_target_group.arn
    container_name   = "ut-api-customer"
    container_port   = var.ut_api_customer_listen_port
  }

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.ut_api_customer_sg.id]
    assign_public_ip = false
  }
}

locals {
  ut_api_customer_manual_variable = [
    for key, value in var.ut_api_manual_env_variables : {
      name      = key
      valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}${value}"
    }
  ]

  ut_api_customer_global_secrets = local.ut_api_customer_manual_variable

  ut_api_customer_task_secret = local.ut_api_customer_global_secrets
}

resource "aws_ecs_task_definition" "ut_api_customer" {
  family       = "ut-api-customer"
  network_mode = "awsvpc"
  cpu          = 4096 # 4 vCPUs
  memory       = 8192 # 8 GiB

  execution_role_arn       = aws_iam_role.ut_api_custom_role.arn
  task_role_arn            = aws_iam_role.ut_api_custom_role.arn
  requires_compatibilities = ["FARGATE"]

  volume {
    name = "workers-customer-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.workers_customer_file_system.id
      transit_encryption = "ENABLED"
      authorization_config {
        iam = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name  = "ut-api-customer",
      image = var.ut_api_customer_registry_uri,
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ut_api_customer.name,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ecs"
        }
      },
      repositoryCredentials = {
        credentialsParameter = aws_secretsmanager_secret.github_container_registry_crdentials.arn
      },
      portMappings = [
        {
          containerPort = var.ut_api_customer_listen_port,
          protocol      = "tcp"
        }
      ],
      mountPoints = [
        {
          sourceVolume  = "workers-customer-data"
          containerPath = "/tmp/uploads"
          readOnly      = false
        }
      ],
      secrets   = local.ut_api_customer_task_secret,
      essential = true
    }
  ])
}

##################
# Security Group #
##################
resource "aws_security_group" "ut_api_customer_sg" {
  name        = "ut-api-customer-sg"
  description = "Controls access to ut api"
  vpc_id      = data.aws_vpc.current-vpc.id
}

resource "aws_security_group_rule" "alb_to_ut_customer_rule" {
  type        = "ingress"
  from_port   = var.ut_listen_port
  to_port     = var.ut_listen_port
  protocol    = "tcp"
  description = "HTTP from ALB"

  source_security_group_id = aws_security_group.public_api_custom_alb_sg.id
  security_group_id        = aws_security_group.ut_api_customer_sg.id
}

resource "aws_security_group_rule" "ut_api_customer_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  description = "Outbound"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_api_customer_sg.id
}


############
# IAM Role #
############

resource "aws_iam_role" "ut_api_custom_role" {
  name = "ut-api-customer-container-exec-role"
  path = "/service-role/fargate/"

  assume_role_policy = data.aws_iam_policy_document.ut_api_custom_role_trust.json
}

resource "aws_iam_role_policy" "ut_api_custom_role_policy" {
  name   = "ut-api-container-policy"
  role   = aws_iam_role.ut_api_custom_role.id
  policy = data.aws_iam_policy_document.ut_api_custom_role_exec.json
}

data "aws_iam_policy_document" "ut_api_custom_role_trust" {
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

data "aws_iam_policy_document" "ut_api_custom_role_exec" {
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
      aws_efs_file_system.workers_customer_file_system.arn
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
    sid = "AllowKms"

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
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

  statement {
    sid = "AllowSecretsManager"

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

  statement {
    sid = "AllowS3AccessForUT"
    actions = [
      "s3:*"
    ]
    resources = [
      aws_s3_bucket.ut_data_bucket.arn,
      "${aws_s3_bucket.ut_data_bucket.arn}/*"
    ]
  }
}
