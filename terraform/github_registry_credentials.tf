###################
# Secrets Manager #
###################
resource "aws_secretsmanager_secret" "github_container_registry_crdentials" {
  name        = "ut-github-container-registry-credentials"
  description = "Credentials used by ECS cluster to pull images from UnderstandTech GitHub container registry"
  policy      = data.aws_iam_policy_document.github_container_registry_policy.json
}

data "aws_iam_policy_document" "github_container_registry_policy" {
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
        aws_iam_role.ut_frontend_container_role.arn,
        aws_iam_role.ut_workers_container_role.arn,
        aws_iam_role.ut_llm_container_role.arn
      ]
    }
  }

}
