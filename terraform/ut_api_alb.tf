#######
# ALB #
#######
resource "aws_lb" "ut_private_cloudfront_origin" {
  #checkov:skip=CKV2_AWS_20:See README.md section security
  name               = "ut-frontend-and-ut-api-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ut_private_cloudfront_origin_sg.id]
  subnets            = var.private_subnets_ids

  enable_deletion_protection = true
  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    enabled = true
  }
}

resource "aws_lb_listener" "ut_http_redirect" {
  #checkov:skip=CKV_AWS_103:See README.md section security
  #checkov:skip=CKV_AWS_2:See README.md section security
  load_balancer_arn = aws_lb.ut_private_cloudfront_origin.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ut_frontend_target_group.arn
  }
}

resource "aws_lb_listener_rule" "ut_api_path_rule" {
  listener_arn = aws_lb_listener.ut_http_redirect.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ut_api_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

resource "aws_lb_target_group" "ut_api_target_group" {
  #checkov:skip=CKV_AWS_378:See README.md section security
  name        = "ut-api-tg"
  port        = local.ut_api_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    interval            = 30
    path                = "/api/docs"
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299,300-399"
  }
}

resource "aws_lb_target_group" "ut_frontend_target_group" {
  #checkov:skip=CKV_AWS_378:See README.md section security
  name        = "ut-frontend-tg"
  port        = local.ut_frontend_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    interval            = 30
    path                = "/index.html"
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}


######################
# ALB Security Group #
######################
resource "aws_security_group" "ut_private_cloudfront_origin_sg" {
  name        = "ut-frontend-alb-sg"
  description = "Controls access to the ut ALB"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ut_alb_http_inbound_from_cloudfront" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  description       = "Requests from cloudfront private origin"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  security_group_id = aws_security_group.ut_private_cloudfront_origin_sg.id
}

resource "aws_security_group_rule" "ut_private_alb_sg_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  description       = "Allow outbound on tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_private_cloudfront_origin_sg.id
}
