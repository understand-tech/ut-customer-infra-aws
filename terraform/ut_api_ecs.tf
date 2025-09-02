#######
# ECS #
#######
resource "aws_ecs_service" "ut_api_service" {
  name                   = "ut-api-service"
  cluster                = aws_ecs_cluster.ut_cluster.id
  task_definition        = aws_ecs_task_definition.ut_api.arn
  launch_type            = "FARGATE"
  desired_count          = 1
  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.ut_api_target_group.arn
    container_name   = "ut-api"
    container_port   = local.ut_api_container_port
  }

  network_configuration {
    subnets          = var.private_subnets_ids
    security_groups  = [aws_security_group.ut_api_sg.id]
    assign_public_ip = false
  }
}

resource "aws_ecs_task_definition" "ut_api" {
  family       = "ut-api"
  network_mode = "awsvpc"
  cpu          = 4096 # 4 vCPUs
  memory       = 8192 # 8 GiB

  execution_role_arn       = aws_iam_role.ut_api_container_role.arn
  task_role_arn            = aws_iam_role.ut_api_container_role_task.arn
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
      name  = "ut-api",
      image = "${var.ut_api_registry_uri}",
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.ut_api.name}",
          awslogs-region        = "${var.aws_region}",
          awslogs-stream-prefix = "ecs"
        }
      },
      repositoryCredentials = {
        credentialsParameter = "${aws_secretsmanager_secret.github_container_registry_crdentials.arn}"
      },
      portMappings = [
        {
          containerPort = "${local.ut_api_container_port}",
          protocol      = "tcp"
        }
      ],
      mountPoints = [
        {
          sourceVolume  = "workers-data"
          containerPath = "/tmp/uploads"
          readOnly      = false
        }
      ],
      secrets = [
        {
          name      = "ADMIN_MAIL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:ADMIN_MAIL::"
        },
        {
          name      = "expected_issuer",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:expected_issuer::"
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
          name      = "GPU_VM_API_TOKEN",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:GPU_VM_API_TOKEN::"
        },
        {
          name      = "GPU_VM_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:LLM_ALB_HOST::"
        },
        {
          name      = "DOMAIN_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:DOMAIN_URL::"
        },
        {
          name      = "jwks_endpoint",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:jwks_endpoint::"
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
          name      = "OPENID_CLIENT_ID",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:OPENID_CLIENT_ID::"
        },
        {
          name      = "OPENID_CLIENT_SECRET",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:OPENID_CLIENT_SECRET::"
        },
        {
          name      = "OPENID_FRONTEND_REDIRECT_URI",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:OPENID_FRONTEND_REDIRECT_URI::"
        },
        {
          name      = "OPENID_SECRET_KEY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:OPENID_SECRET_KEY::"
        },
        {
          name      = "openid_scope",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:openid_scope::"
        },
        {
          name      = "REDIS_HOST",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:REDIS_HOST::"
        },
        {
          name      = "SENDGRID_API_KEY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:SENDGRID_API_KEY::"
        },
        {
          name      = "server_metadata_url",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:server_metadata_url::"
        },
        {
          name      = "token_endpoint",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:token_endpoint::"
        },
        {
          name      = "UT_USERS_DATA_BUCKET",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:UT_USERS_DATA_BUCKET::"
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
          name      = "S3_REGION",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:S3_REGION::"
        },
        {
          name      = "BACKEND_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:BACKEND_URL::"
        }
      ],
      essential = true
    }
  ])
}


##################
# Security Group #
##################
resource "aws_security_group" "ut_api_sg" {
  name        = "ut-api-sg"
  description = "Controls access to ut-api containers"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "alb_to_ut_api_rule" {
  type        = "ingress"
  from_port   = local.ut_api_container_port
  to_port     = local.ut_api_container_port
  protocol    = "tcp"
  description = "Requests from ut-frontend ALB"

  source_security_group_id = aws_security_group.ut_private_cloudfront_origin_sg.id
  security_group_id        = aws_security_group.ut_api_sg.id
}

resource "aws_security_group_rule" "ut_api_egress_rule" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  description       = "Outbound"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_api_sg.id
}


############
# IAM Role #
############
resource "aws_iam_role" "ut_api_container_role" {
  name = "ut-api-container-exec-role"
  path = "/service-role/fargate/"

  assume_role_policy = data.aws_iam_policy_document.ut_api_role_trust.json
}

resource "aws_iam_role" "ut_api_container_role_task" {
  name = "ut-api-container-task-role"
  path = "/service-role/fargate/"

  assume_role_policy = data.aws_iam_policy_document.ut_api_role_trust.json
}

resource "aws_iam_role_policy" "ut_api_role_policy" {
  name   = "ut-api-container-policy"
  role   = aws_iam_role.ut_api_container_role.id
  policy = data.aws_iam_policy_document.ut_api_role_exec.json
}

resource "aws_iam_role_policy" "ut_api_role_policy_task" {
  name   = "ut-api-container-task-policy"
  role   = aws_iam_role.ut_api_container_role_task.id
  policy = data.aws_iam_policy_document.ut_api_role_exec.json
}

data "aws_iam_policy_document" "ut_api_role_trust" {
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

data "aws_iam_policy_document" "ut_api_role_exec" {
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
resource "aws_cloudwatch_log_group" "ut_api" {
  #checkov:skip=CKV_AWS_158:KMS should be handle by the final customer
  name              = "/ecs/ut-api"
  retention_in_days = 365
}
