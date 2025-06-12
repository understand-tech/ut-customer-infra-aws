#######
# ECS #
#######
resource "aws_ecs_service" "ut_llm_service" {
  name                   = "ut-llm-service"
  cluster                = aws_ecs_cluster.ut_cluster.id
  task_definition        = aws_ecs_task_definition.ut_llm.arn
  desired_count          = 1
  enable_execute_command = true

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  # LLM container initialization time
  health_check_grace_period_seconds = 120

  load_balancer {
    target_group_arn = aws_lb_target_group.ut_llm_target_group.arn
    container_name   = "llm"
    container_port   = local.ut_llm_container_port
  }

  network_configuration {
    subnets          = var.private_subnets_ids
    security_groups  = [aws_security_group.ut_llm_sg.id]
    assign_public_ip = false
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ut_llm_capacity_provider.name
    base              = 1
    weight            = 100
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
}

resource "aws_ecs_task_definition" "ut_llm" {
  family       = "ut-llm"
  network_mode = "awsvpc"
  cpu          = "43000"  # ~86 vCPUs
  memory       = "180224" # ~176 GiB

  execution_role_arn       = aws_iam_role.ut_llm_container_role.arn
  task_role_arn            = aws_iam_role.ut_llm_container_role.arn
  requires_compatibilities = ["EC2"]

  volume {
    name = "llm-ollama"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.ut_llm_ollama_file_system.id
      transit_encryption = "ENABLED"
      authorization_config {
        iam = "ENABLED"
      }
    }
  }

  volume {
    name = "llm-models"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.ut_llm_models_file_system.id
      transit_encryption = "ENABLED"
      authorization_config {
        iam = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name  = "llm",
      image = "${var.llm_registry_uri}",
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.ut_llm.name}",
          awslogs-region        = "${var.aws_region}",
          awslogs-stream-prefix = "ecs"
        }
      },
      repositoryCredentials = {
        credentialsParameter = "${aws_secretsmanager_secret.github_container_registry_crdentials.arn}"
      },
      portMappings = [
        {
          containerPort = "${local.ut_llm_container_port}",
          protocol      = "tcp"
        }
      ],
      secrets = [
        {
          name      = "MONGODB_PASSWORD",
          valueFrom = "${aws_secretsmanager_secret.ut_mongodb_password.arn}:MONGODB_PASSWORD::"
        },
        {
          name      = "MONGODB_HOST",
          valueFrom = "${aws_secretsmanager_secret.ut_mongodb_password.arn}:MONGODB_HOST::"
        },
        {
          name      = "MONGODB_PORT",
          valueFrom = "${aws_secretsmanager_secret.ut_mongodb_password.arn}:MONGODB_PORT::"
        },
        {
          name      = "MONGODB_DATABASE",
          valueFrom = "${aws_secretsmanager_secret.ut_mongodb_password.arn}:MONGODB_DATABASE::"
        },
        {
          name      = "MONGODB_USERNAME",
          valueFrom = "${aws_secretsmanager_secret.ut_mongodb_password.arn}:MONGODB_USERNAME::"
        },
        {
          name      = "UT_USERS_DATA_BUCKET",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:UT_USERS_DATA_BUCKET::"
        },
        {
          name      = "REDIS_HOST",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:REDIS_HOST::"
        },
        {
          name      = "OLLAMA_MODEL_LLM",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:OLLAMA_MODEL_LLM::"
        },
        {
          name      = "OLLAMA_MODEL_CONDENSE_LLM",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:OLLAMA_MODEL_CONDENSE_LLM::"
        },
        {
          name      = "OLLAMA_HOST_PORT",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:OLLAMA_HOST_PORT::"
        },
        {
          name      = "MODELS_DIR",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:MODELS_DIR::"
        },
        {
          name      = "EMBED_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:EMBED_URL::"
        },
        {
          name      = "EMBED_MODEL_NAME",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:EMBED_MODEL_NAME::"
        },
        {
          name      = "RERANKER_HF_PATH",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:RERANKER_HF_PATH::"
        },
        {
          name      = "RERANKER_MODEL_NAME",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:RERANKER_MODEL_NAME::"
        },
        {
          name      = "GPU_VM_API_TOKEN",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:GPU_VM_API_TOKEN::"
        },
        {
          name      = "S3_REGION",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:S3_REGION::"
        }
      ],
      mountPoints = [
        {
          sourceVolume  = "llm-ollama"
          containerPath = "/root/.ollama"
          readOnly      = false
        },
        {
          sourceVolume  = "llm-models"
          containerPath = "/root/models"
          readOnly      = false
        }
      ],
      resourceRequirements = [
        {
          "type" : "GPU"
          "value" : "4"
        }
      ],
      essential = true
    }
  ])
}


##################
# Security Group #
##################
resource "aws_security_group" "ut_llm_sg" {
  name        = "ut-llm-sg"
  description = "Controls access to LLM containers"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "alb_to_LLM_rule" {
  type        = "ingress"
  from_port   = local.ut_llm_container_port
  to_port     = local.ut_llm_container_port
  protocol    = "tcp"
  description = "Requests from ut-llm ALB"

  source_security_group_id = aws_security_group.ut_llm_alb_sg.id
  security_group_id        = aws_security_group.ut_llm_sg.id
}

resource "aws_security_group_rule" "llm_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  description = "Outbound"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_llm_sg.id
}


############
# IAM Role #
############
resource "aws_iam_role" "ut_llm_container_role" {
  name = "ut-llm-container-exec-role"
  path = "/service-role/fargate/"

  assume_role_policy = data.aws_iam_policy_document.llm_role_trust.json
}

resource "aws_iam_role_policy" "llm_role_policy" {
  name   = "llm-container-policy"
  role   = aws_iam_role.ut_llm_container_role.id
  policy = data.aws_iam_policy_document.llm_role_exec.json
}

data "aws_iam_policy_document" "llm_role_trust" {
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

data "aws_iam_policy_document" "llm_role_exec" {
  statement {
    sid = "AllowSsm"

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
      aws_efs_file_system.ut_llm_models_file_system.arn,
      aws_efs_file_system.ut_llm_ollama_file_system.arn
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
resource "aws_cloudwatch_log_group" "ut_llm" {
  name              = "/ecs/ut-llm"
  retention_in_days = 30
}
