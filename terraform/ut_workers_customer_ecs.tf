#######
# ECS #
#######
resource "aws_ecs_service" "workers_customer_service" {
  name                   = "ut-workers-customer-service"
  cluster                = aws_ecs_cluster.ecs_cluster.id
  task_definition        = aws_ecs_task_definition.workers_customer.arn
  launch_type            = "FARGATE"
  desired_count          = var.ut_workers_customer_desired_count
  enable_execute_command = true

  network_configuration {
    subnets          = data.aws_subnets.private.ids
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
  task_role_arn            = aws_iam_role.ut_workers_customer_role.arn
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
        "rq worker --url redis://$REDIS_HOST:$REDIS_PORT"
      ],
      mountPoints = [
        {
          sourceVolume  = "workers-customer-data"
          containerPath = "/tmp/uploads"
          readOnly      = false
        }
      ],
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
          name      = "GPU_VM_API_TOKEN",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:GPU_VM_API_TOKEN::"
        },
        {
          name      = "DEEPSEEK_API_KEY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:DEEPSEEK_API_KEY::"
        },
        {
          name      = "XAI_API_KEY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:XAI_API_KEY::"
        },
        {
          name      = "PERPLEXITY_API_KEY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:PERPLEXITY_API_KEY::"
        },
        {
          name      = "OA_KEY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:OA_KEY::"
        },
        {
          name      = "UT_KEY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:UT_KEY::"
        },
        {
          name      = "MISTRAL_API_KEY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:MISTRAL_API_KEY::"
        },
        {
          name      = "CLAUDE_API_KEY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:OA_KEY::"
        },
        {
          name      = "GOOGLE_API_KEY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:GOOGLE_API_KEY::"
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
          name      = "MICROSOFT_AUTHORITY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:MICROSOFT_AUTHORITY::"
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
          name      = "ZOHO_CLIENT_ID",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:ZOHO_CLIENT_ID::"
        },
        {
          name      = "ZOHO_CLIENT_SECRET",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:ZOHO_CLIENT_SECRET::"
        },
        {
          name      = "ZOHO_AUTH_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:ZOHO_AUTH_URL::"
        },
        {
          name      = "ZOHO_TOKEN_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:ZOHO_TOKEN_URL::"
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
          name      = "jwks_endpoint",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:jwks_endpoint::"
        },
        {
          name      = "expected_issuer",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:expected_issuer::"
        },
        {
          name      = "openid_scope",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:openid_scope::"
        },
        {
          name      = "OPENID_FRONTEND_REDIRECT_URI",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:OPENID_FRONTEND_REDIRECT_URI::"
        },
        {
          name      = "ADMIN_MAIL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:ADMIN_MAIL::"
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
          name      = "OPENID_SECRET_KEY",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:OPENID_SECRET_KEY::"
        },
        {
          name      = "storageBucket",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:storageBucket::"
        },
        {
          name      = "databaseURL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:databaseURL::"
        },
        {
          name      = "apiKey",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:apiKey::"
        },
        {
          name      = "authDomain",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:authDomain::"
        },
        {
          name      = "projectId",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:projectId::"
        },
        {
          name      = "messagingSenderId",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:messagingSenderId::"
        },
        {
          name      = "appId",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:appId::"
        },
        {
          name      = "measurementId",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:measurementId::"
        },
        {
          name      = "stripe_price_new_team_test",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:stripe_price_new_team_test::"
        },
        {
          name      = "stripe_price_new_enterprise_test",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:stripe_price_new_enterprise_test::"
        },
        {
          name      = "stripe_price_premium_test",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:stripe_price_premium_test::"
        },
        {
          name      = "stripe_price_team_test",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:stripe_price_team_test::"
        },
        {
          name      = "stripe_price_team_plus_test",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:stripe_price_team_plus_test::"
        },
        {
          name      = "stripe_price_enterprise",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:stripe_price_enterprise::"
        },
        {
          name      = "stripe_url",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:stripe_url::"
        },
        {
          name      = "stripe_api_key",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:stripe_api_key::"
        },
        {
          name      = "serviceAccountKey",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:serviceAccountKey::"
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
  vpc_id      = data.aws_vpc.current-vpc.id
}

resource "aws_security_group_rule" "workers_customer_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
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

resource "aws_iam_role_policy" "workers_customer_role_policy" {
  name   = "workers-customer-container-policy"
  role   = aws_iam_role.ut_workers_customer_role.id
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
