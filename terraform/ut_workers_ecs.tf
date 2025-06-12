#######
# ECS #
#######
resource "aws_ecs_service" "ut_workers_service" {
  name                   = "ut-workers-service"
  cluster                = aws_ecs_cluster.ut_cluster.id
  task_definition        = aws_ecs_task_definition.ut_workers.arn
  launch_type            = "FARGATE"
  desired_count          = 2
  enable_execute_command = true

  network_configuration {
    subnets          = var.private_subnets_ids
    security_groups  = [aws_security_group.ut_workers_sg.id]
    assign_public_ip = false
  }
}

resource "aws_ecs_task_definition" "ut_workers" {
  family       = "ut-workers"
  network_mode = "awsvpc"
  cpu          = 4096 # 4 vCPUs
  memory       = 8192 # 8 GiB

  execution_role_arn       = aws_iam_role.ut_workers_container_role.arn
  task_role_arn            = aws_iam_role.ut_workers_container_role.arn
  requires_compatibilities = ["FARGATE"]

  volume {
    name = "workers-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.ut_workers_file_system.id
      transit_encryption = "ENABLED"
      authorization_config {
        iam = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name  = "ut-worker",
      image = "${var.ut_worker_registry_uri}",
      command = [
        "sh",
        "-c",
        "rq worker --url redis://$REDIS_HOST:${local.ut_redis_port}"
      ],
      mountPoints = [
        {
          sourceVolume  = "workers-data"
          containerPath = "/tmp/uploads"
          readOnly      = false
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.ut_workers.name}",
          awslogs-region        = "${var.aws_region}",
          awslogs-stream-prefix = "ecs"
        }
      },
      repositoryCredentials = {
        credentialsParameter = "${aws_secretsmanager_secret.github_container_registry_crdentials.arn}"
      },
      secrets = [
        {
          name      = "REDIS_HOST",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:REDIS_HOST::"
        },
        {
          name      = "UT_USERS_DATA_BUCKET",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:UT_USERS_DATA_BUCKET::"
        },
        {
          name      = "MONGODB_DATABASE",
          valueFrom = "${aws_secretsmanager_secret.ut_mongodb_password.arn}:MONGODB_DATABASE::"
        },
        {
          name      = "MONGODB_HOST",
          valueFrom = "${aws_secretsmanager_secret.ut_mongodb_password.arn}:MONGODB_HOST::"
        },
        {
          name      = "MONGODB_PASSWORD",
          valueFrom = "${aws_secretsmanager_secret.ut_mongodb_password.arn}:MONGODB_PASSWORD::"
        },
        {
          name      = "MONGODB_PORT",
          valueFrom = "${aws_secretsmanager_secret.ut_mongodb_password.arn}:MONGODB_PORT::"
        },
        {
          name      = "MONGODB_USERNAME",
          valueFrom = "${aws_secretsmanager_secret.ut_mongodb_password.arn}:MONGODB_USERNAME::"
        },
        {
          name      = "GPU_VM_API_TOKEN",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:GPU_VM_API_TOKEN::"
        },
        {
          name      = "GPU_VM_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:LLM_ALB_HOST::"
        },
        {
          name      = "MICROSOFT_AUTHORITY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:MICROSOFT_AUTHORITY::"
        },
        {
          name      = "MICROSOFT_CLIENT_ID",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:MICROSOFT_CLIENT_ID::"
        },
        {
          name      = "MICROSOFT_CLIENT_SECRET",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:MICROSOFT_CLIENT_SECRET::"
        },
        {
          name      = "GOOGLE_CLIENT_ID",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:GOOGLE_CLIENT_ID::"
        },
        {
          name      = "GOOGLE_CLIENT_SECRET",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:GOOGLE_CLIENT_SECRET::"
        },
        {
          name      = "ZOHO_AUTH_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:ZOHO_AUTH_URL::"
        },
        {
          name      = "ZOHO_CLIENT_ID",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:ZOHO_CLIENT_ID::"
        },
        {
          name      = "ZOHO_CLIENT_SECRET",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:ZOHO_CLIENT_SECRET::"
        },
        {
          name      = "ZOHO_TOKEN_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:ZOHO_TOKEN_URL::"
        },
        {
          name      = "DOMAIN_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:DOMAIN_URL::"
        },
        {
          name      = "S3_REGION",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:S3_REGION::"
        }
      ],
      essential = true,

    }
  ])
}


##################
# Security Group #
##################
resource "aws_security_group" "ut_workers_sg" {
  name        = "ut-workers-sg"
  description = "Controls access to ut-workers containers"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ut_workers_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  description = "Outbound"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_workers_sg.id
}


############
# IAM Role #
############
resource "aws_iam_role" "ut_workers_container_role" {
  name = "ut-workers-container-exec-role"
  path = "/service-role/fargate/"

  assume_role_policy = data.aws_iam_policy_document.ut_workers_role_trust.json
}

resource "aws_iam_role_policy" "ut_workers_role_policy" {
  name   = "ut-workers-container-policy"
  role   = aws_iam_role.ut_workers_container_role.id
  policy = data.aws_iam_policy_document.ut_workers_role_exec.json
}

data "aws_iam_policy_document" "ut_workers_role_trust" {
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

data "aws_iam_policy_document" "ut_workers_role_exec" {
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
      aws_efs_file_system.ut_workers_file_system.arn
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


###################
# CloudWatch Logs #
###################
resource "aws_cloudwatch_log_group" "ut_workers" {
  name              = "/ecs/ut-workers"
  retention_in_days = 30
}
