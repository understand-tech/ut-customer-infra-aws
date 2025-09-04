#######
# ECS #
#######
resource "aws_ecs_service" "ut_frontend_service" {
  name                   = "ut-frontend-service"
  cluster                = aws_ecs_cluster.ut_cluster.id
  task_definition        = aws_ecs_task_definition.ut_frontend.arn
  launch_type            = "FARGATE"
  desired_count          = 1
  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.ut_frontend_target_group.arn
    container_name   = "ut-frontend"
    container_port   = local.ut_frontend_container_port
  }

  network_configuration {
    subnets          = var.private_subnets_ids
    security_groups  = [aws_security_group.ut_frontend_sg.id]
    assign_public_ip = false
  }
}


resource "aws_ecs_task_definition" "ut_frontend" {
  family       = "ut-frontend"
  network_mode = "awsvpc"
  cpu          = 256
  memory       = 512

  execution_role_arn       = aws_iam_role.ut_frontend_container_role.arn
  task_role_arn            = aws_iam_role.ut_frontend_container_role_task.arn
  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode([
    {
      name  = "ut-frontend",
      image = "${var.ut_frontend_registry_uri}",
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.ut_frontend.name}",
          awslogs-region        = "${var.aws_region}",
          awslogs-stream-prefix = "ecs"
        }
      },
      secrets = [
        {
          name      = "DOMAIN_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:DOMAIN_URL::"
        },
        {
          name      = "BACKEND_URL",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret_automation.arn}:BACKEND_URL::"
        },
        {
          name      = "URL_API_REST",
          valueFrom = "${aws_secretsmanager_secret.ut_api_secret.arn}:URL_API_REST::"
        }

      ],
      repositoryCredentials = {
        credentialsParameter = "${aws_secretsmanager_secret.github_container_registry_crdentials.arn}"
      },
      portMappings = [
        {
          containerPort = "${local.ut_frontend_container_port}",
          protocol      = "tcp"
        }
      ],
      essential = true
    }
  ])
}


##################
# Security Group #
##################
resource "aws_security_group" "ut_frontend_sg" {
  name        = "ut-frontend-sg"
  description = "Controls access to ut frontend containers"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "alb_to_front_rule" {
  type        = "ingress"
  from_port   = local.ut_frontend_container_port
  to_port     = local.ut_frontend_container_port
  protocol    = "tcp"
  description = "Requests from Cloudfront ALB"

  source_security_group_id = aws_security_group.ut_private_cloudfront_origin_sg.id
  security_group_id        = aws_security_group.ut_frontend_sg.id
}

resource "aws_security_group_rule" "ut_frontend_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  description = "Outbound"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_frontend_sg.id
}


############
# IAM Role #
############
resource "aws_iam_role" "ut_frontend_container_role" {
  name = "ut-frontend-container-exec-role"
  path = "/service-role/fargate/"

  assume_role_policy = data.aws_iam_policy_document.ut_frontend_role_trust.json
}

resource "aws_iam_role" "ut_frontend_container_role_task" {
  name = "ut-frontend-container-task-role"
  path = "/service-role/fargate/"

  assume_role_policy = data.aws_iam_policy_document.ut_frontend_role_trust.json
}

resource "aws_iam_role_policy" "ut_frontend_role_policy" {
  name   = "ut-frontend-container-policy"
  role   = aws_iam_role.ut_frontend_container_role.id
  policy = data.aws_iam_policy_document.ut_frontend_role_exec.json
}

resource "aws_iam_role_policy" "ut_frontend_role_policy_task" {
  name   = "ut-frontend-container-task-policy"
  role   = aws_iam_role.ut_frontend_container_role_task.id
  policy = data.aws_iam_policy_document.ut_frontend_role_exec.json
}

data "aws_iam_policy_document" "ut_frontend_role_trust" {
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

data "aws_iam_policy_document" "ut_frontend_role_exec" {
  statement {
    sid = "AllowLogs"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/ut-api-customer:*"
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
      "ut-*"
    ]
  }
}


###################
# CloudWatch Logs #
###################
resource "aws_cloudwatch_log_group" "ut_frontend" {
  #checkov:skip=CKV_AWS_158:KMS should be handle by the final customer
  name              = "/ecs/ut-frontend"
  retention_in_days = 365
}
