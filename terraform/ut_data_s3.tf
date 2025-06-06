resource "aws_s3_bucket" "ut_data_bucket" {
  bucket_prefix = "ut-users-data-"

  tags = {
    Name = "ut-users-data"
  }
}

resource "aws_s3_bucket_public_access_block" "ut_data_block" {
  bucket = aws_s3_bucket.ut_data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_policy" "ut_data_bucket_policy" {
  bucket = aws_s3_bucket.ut_data_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement : [
      {
        Sid : "AllowECSRoles",
        Effect : "Allow",
        Principal : {
          AWS : [
            aws_iam_role.ut_api_container_role.arn,
            aws_iam_role.ut_llm_container_role.arn
          ]
        },
        Action : [
          "s3:*"
        ],
        Resource : [
          aws_s3_bucket.ut_data_bucket.arn,
          "${aws_s3_bucket.ut_data_bucket.arn}/*"
        ]
      }
    ]
  })
}
