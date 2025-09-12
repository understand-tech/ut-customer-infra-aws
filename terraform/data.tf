data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

data "aws_cloudfront_response_headers_policy" "security" {
  name = "Managed-CORS-and-SecurityHeadersPolicy"
}