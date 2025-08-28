resource "aws_sns_topic" "bucket_notifications" {
  name = "ut-bucket-notifications"

  kms_master_key_id = "alias/aws/sns"
  policy            = data.aws_iam_policy_document.bucket_notifications.json
}

data "aws_iam_policy_document" "bucket_notifications" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "s3.amazonaws.com"
      ]
    }

    actions = [
      "SNS:Publish"
    ]
    resources = [
      "arn:aws:sns:*:*:ut-bucket-notifications"
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        aws_s3_bucket.logs.arn,
        aws_s3_bucket.ut_data_bucket.arn
      ]
    }
  }
}