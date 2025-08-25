#############
# S3 bucket #
#############
resource "aws_s3_bucket" "logs" {
  #checkov:skip=CKV_AWS_145:KMS should be handle by the final customer
  bucket = "ut-logs"
}

resource "aws_s3_bucket_public_access_block" "logs_public_access" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle_policy" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id = "transition-to-ia"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 365
    }

    filter {
      prefix = ""
    }

    status = "Enabled"
  }

  rule {
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    filter {
      prefix = ""
    }

    id     = "remove-incomplete"
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encryption" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "logs_policy" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_policy.json
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "logs_policy" {
  statement {
    sid    = "AllowDelivery"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    principals {
      type = "Service"
      identifiers = [
        "logdelivery.elasticloadbalancing.amazonaws.com",
        "delivery.logs.amazonaws.com"
      ]
    }
    resources = ["arn:aws:s3:::ut-logs/AWSLogs/${var.aws_account_id}/*"]
  }

  statement {
    sid    = "AllowAdministrator"
    effect = "Allow"
    actions = [
      "s3:*"
    ]

    principals {
      type        = "AWS"
      identifiers = [
        "arn:aws:iam::${var.aws_account_id}:root"
      ]
    }

    resources = [
      "arn:aws:s3:::ut-logs",
      "arn:aws:s3:::ut-logs/*"
    ]
  }
}