###################
# Secrets Manager #
###################
resource "aws_secretsmanager_secret" "ut_api_secret" {
  #checkov:skip=CKV_AWS_149:KMS should be handle by the final customer
  #checkov:skip=CKV2_AWS_57:Not Need for rotation here
  name   = "ut-api-secret_manual"
  policy = data.aws_iam_policy_document.task_secrets_generic_policy.json
}

resource "aws_secretsmanager_secret" "ut_api_secret_automation" {
  #checkov:skip=CKV_AWS_149:KMS should be handle by the final customer
  #checkov:skip=CKV2_AWS_57:Not Need for rotation here
  name   = "ut-api-secret-automation"
  policy = data.aws_iam_policy_document.task_secrets_generic_policy.json
}

resource "aws_secretsmanager_secret_version" "ut_api_secret_automation_version" {
  secret_id = aws_secretsmanager_secret.ut_api_secret_automation.id

  secret_string = jsonencode({
    REDIS_HOST           = aws_elasticache_cluster.redis.cache_nodes[0].address
    LLM_ALB_HOST         = "http://${aws_lb.ut_llm_alb.dns_name}:80"
    UT_USERS_DATA_BUCKET = aws_s3_bucket.ut_data_bucket.bucket
    DOMAIN_URL           = "https://${aws_cloudfront_distribution.ut_frontend_distribution.domain_name}/"
    BACKEND_URL          = "https://${aws_cloudfront_distribution.ut_frontend_distribution.domain_name}/api"
    S3_REGION            = var.aws_region
  })
}

resource "random_password" "mongodb_password" {
  length           = 16
  special          = true
  override_special = "!#*-_=+:?"
}

locals {
  mongodb_secrets = {
    MONGODB_PASSWORD = "${random_password.mongodb_password.result}"
    MONGODB_HOST     = "${aws_lb.ut_mongodb.dns_name}"
    MONGODB_PORT     = "${local.ut_mongodb_container_port}"
    MONGODB_DATABASE = "ut-db"
    MONGODB_USERNAME = "mongoadmin"
  }
}

resource "aws_secretsmanager_secret" "ut_mongodb_password" {
  #checkov:skip=CKV_AWS_149:KMS should be handle by the final customer
  #checkov:skip=CKV2_AWS_57:Not Need for rotation here
  name   = "mongodb-password"
  policy = data.aws_iam_policy_document.task_secrets_generic_policy.json
}

resource "aws_secretsmanager_secret_version" "ut_mongodb_password" {
  secret_id     = aws_secretsmanager_secret.ut_mongodb_password.id
  secret_string = jsonencode(local.mongodb_secrets)
}


#################
# Secret Policy #
#################
data "aws_iam_policy_document" "task_secrets_generic_policy" {
  statement {
    sid       = "AllowDeployer"
    effect    = "Allow"
    actions   = ["secretsmanager:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [var.deployment_role_arn]
    }
  }

  statement {
    sid       = "AllowAdministration"
    effect    = "Allow"
    actions   = ["secretsmanager:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [var.admin_role_arn]
    }
  }

  statement {
    sid    = "AllowDescribe"
    effect = "Allow"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:root"]
    }
  }

  statement {
    sid    = "AllowECSClusterAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = [
      "*"
    ]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.ut_api_container_role.arn,
        aws_iam_role.ut_workers_container_role.arn,
        aws_iam_role.ut_mongodb_container_role.arn
      ]
    }
  }
}
