##############
# VPC Origin #
##############
resource "aws_cloudfront_vpc_origin" "ut_frontend_alb" {
  vpc_origin_endpoint_config {
    name                   = "ut-frontend-private-cloudfront-origin-alb"
    arn                    = aws_lb.ut_private_cloudfront_origin.arn
    http_port              = 80
    https_port             = 8443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
}


###########################
# Cloudfront Distribution #
###########################
resource "aws_cloudfront_distribution" "ut_frontend_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = var.cloudfront_alternate_domain_list

  origin {
    domain_name = aws_lb.ut_private_cloudfront_origin.dns_name
    origin_id   = "defaultALBOrigin"

    vpc_origin_config {
      vpc_origin_id = aws_cloudfront_vpc_origin.ut_frontend_alb.id
    }
  }

  default_cache_behavior {
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    target_origin_id         = "defaultALBOrigin"
    viewer_protocol_policy   = "redirect-to-https"
    min_ttl                  = 0
    default_ttl              = 3600
    max_ttl                  = 86400
    compress                 = true
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.ut_spa_redirect.arn
    }
  }


  price_class = "PriceClass_200"
  # Price class list : https://docs.aws.amazon.com/cdk/api/v2/python/aws_cdk.aws_cloudfront/PriceClass.html

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.cloudfront_acm_certificat_arn != "" ? var.cloudfront_acm_certificat_arn : null
    cloudfront_default_certificate = var.cloudfront_acm_certificat_arn == "" ? true : false
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
    # Cloudfront ciphers list : https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/secure-connections-supported-viewer-protocols-ciphers.html
  }

  provider = aws.NVirginia
}

resource "aws_cloudfront_function" "ut_spa_redirect" {
  name    = "ut-spa-redirect"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = file("${path.module}/lambda/spa_redirect/spa_redirect.js")
}
