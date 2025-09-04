#######
# ECS #
#######
resource "aws_ecs_service" "workers_customer_service" {
  name                   = "ut-workers-customer-service"
  cluster                = aws_ecs_cluster.ut_cluster.id
  task_definition        = aws_ecs_task_definition.workers_customer.arn
  launch_type            = "FARGATE"
  desired_count          = var.ut_workers_customer_desired_count
  enable_execute_command = true

  network_configuration {
    subnets          = var.private_subnets_ids
    security_groups  = [aws_security_group.workers_customer_sg.id]
    assign_public_ip = false
  }
}

resource "aws_ecs_task_definition" "workers_customer" {
  family       = "ut-workers-customer"
  network_mode = "awsvpc"
  cpu          = 4096 # 4 vCPUs
  memory       = 8192 # 8 GiB

  execution_role_arn       = aws_iam_role.ut_workers_customer_role.arn
  task_role_arn            = aws_iam_role.ut_workers_customer_role_task.arn
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
      name  = "ut-worker-customer",
      image = "${var.worker_customer_registry_uri}",
      command = [
        "sh",
        "-c",
        "rq worker --url redis://$REDIS_HOST:$REDIS_PORT ut-api-partners"
      ],
      mountPoints = [
        {
          sourceVolume  = "workers-customer-data"
          containerPath = "/tmp/uploads"
          readOnly      = false
        }
      ],
      readonlyRootFilesystem = true,
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.workers_customer.name}",
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
      ]
      essential = true,

    }
  ])
}

##################
# Security Group #
##################
resource "aws_security_group" "workers_customer_sg" {
  name        = "workers-customer-sg"
  description = "Controls access to ut-workers-customer"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "workers_customer_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  description = "Allow outbound on tcp"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.workers_customer_sg.id
}

############
# IAM Role #
############
resource "aws_iam_role" "ut_workers_customer_role" {
  name = "ut-workers-customer-container-exec-role"
  path = "/service-role/fargate/"

  assume_role_policy = data.aws_iam_policy_document.workers_customer_role_trust.json
}

resource "aws_iam_role" "ut_workers_customer_role_task" {
  name = "ut-workers-customer-container-task-role"
  path = "/service-role/fargate/"

  assume_role_policy = data.aws_iam_policy_document.workers_customer_role_trust.json
}

resource "aws_iam_role_policy" "workers_customer_role_policy" {
  name   = "workers-customer-container-policy"
  role   = aws_iam_role.ut_workers_customer_role.id
  policy = data.aws_iam_policy_document.workers_customer_role_exec.json
}

resource "aws_iam_role_policy" "workers_customer_role_policy_task" {
  name   = "workers-customer-container-task-policy"
  role   = aws_iam_role.ut_workers_customer_role_task.id
  policy = data.aws_iam_policy_document.workers_customer_role_exec.json
}

data "aws_iam_policy_document" "workers_customer_role_trust" {
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

data "aws_iam_policy_document" "workers_customer_role_exec" {
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
      "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/ut-workers-customer:*"
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
      "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:ut-*"
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
