#######
# EFS #
#######
resource "aws_efs_file_system" "workers_customer_file_system" {
  creation_token = "workers-customer-efs"

  encrypted  = true
  kms_key_id = aws_kms_key.workers.arn

  tags = {
    Name = "workers-customer-efs"
  }
}

resource "aws_efs_mount_target" "workers_customer_efs_mount_target" {
  for_each = toset(data.aws_subnets.private.ids)

  file_system_id  = aws_efs_file_system.workers_customer_file_system.id
  subnet_id       = each.value
  security_groups = [aws_security_group.workers_customer_efs_sg.id]
}

###########
# KMS Key #
###########
resource "aws_kms_key" "workers_customer" {
  description             = "KMS key for workers-customer file system"
  deletion_window_in_days = 10

  policy = data.aws_iam_policy_document.workers_customer_kms_policy.json
}

resource "aws_kms_alias" "workers_customer_key_alias" {
  name          = "alias/workers-customer-efs-key"
  target_key_id = aws_kms_key.workers.key_id
}

data "aws_iam_policy_document" "workers_customer_kms_policy" {
  statement {
    sid       = "AllowDeployer"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.aws_account_id}:role/github-actions-pipelines"
      ]
    }
  }
  statement {
    sid       = "AllowAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:root"]
    }

    condition {
      test     = "ForAnyValue:ArnLikeIfExists"
      variable = "aws:PrincipalArn"

      values = [
        "arn:aws:iam::${var.aws_account_id}:role/AWSReservedSSO_cloud-admin_*",
      ]
    }
  }

  statement {
    sid    = "AllowDescribe"
    effect = "Allow"
    actions = [
      "kms:GetKeyPolicy",
      "kms:DescribeKey",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:root"]
    }
  }

  statement {
    sid    = "AllowALBAccess"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:root"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values = [
        "elasticfilesystem.*amazonaws.com"
      ]
    }
  }
}

##################
# Security Group #
##################
resource "aws_security_group" "workers_customer_efs_sg" {
  name        = "workers-customer-efs-sg"
  description = "Controls access to workers-customer efs"
  vpc_id      = data.aws_vpc.current-vpc.id
}

resource "aws_security_group_rule" "ut_api_customer_to_efs_customer_rule" {
  type        = "ingress"
  from_port   = 2049
  to_port     = 2049
  protocol    = "tcp"
  description = "Requests from ut-api containers"

  source_security_group_id = aws_security_group.ut_api_customer_sg.id
  security_group_id        = aws_security_group.workers_customer_efs_sg.id
}

resource "aws_security_group_rule" "workers_customer_to_efs_customer_rule" {
  type        = "ingress"
  from_port   = 2049
  to_port     = 2049
  protocol    = "tcp"
  description = "Requests from workers-customer containers"

  source_security_group_id = aws_security_group.workers_customer_sg.id
  security_group_id        = aws_security_group.workers_customer_efs_sg.id
}

resource "aws_security_group_rule" "workers_customer_efs_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "tcp"
  description = "Allow outbound on tcp"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.workers_customer_efs_sg.id
}
