resource "aws_sns_topic" "bucket_notifications" {
  name = "ut-bucket-notifications"

  kms_master_key_id = "alias/aws/sns"
}