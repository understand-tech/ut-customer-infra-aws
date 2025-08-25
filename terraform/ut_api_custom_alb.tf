#######
# ALB #
#######

resource "aws_lb" "public_api_custom_alb" {
  name               = "ut-api-custom-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_api_custom_alb_sg.id]
  subnets            = var.public_subnets_ids

  enable_deletion_protection = true
  drop_invalid_header_fields = true
  idle_timeout               = 120

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    enabled = true
  }
}

# resource "aws_lb_listener" "ut_https_api_custom_redirect" {
#   load_balancer_arn = aws_lb.public_api_custom_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.ut_api_custom_target_group.arn
#   }
# }

resource "aws_lb_listener" "ut_https_api_custom_redirect" {
  load_balancer_arn = aws_lb.public_api_custom_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ut_api_custom_target_group.arn
  }
}

# resource "aws_lb_listener" "ut_http_api_custom_redirect" {
#   load_balancer_arn = aws_lb.public_api_custom_alb.arn
#   port              = 80
#   protocol          = "HTTP"
#
#   default_action {
#     type = "redirect"
#
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }


resource "aws_lb_target_group" "ut_api_custom_target_group" {
  name        = "ut-api-custom-tg"
  port        = var.ut_listen_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    interval            = 30
    path                = "/api/v1/docs"
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299,300-399"
  }
}


######################
# ALB Security Group #
######################

resource "aws_security_group" "public_api_custom_alb_sg" {
  description = "Controls access to the ut customer ALB"

  vpc_id = var.vpc_id
  name   = "app-ut-custom-alb"
}

resource "aws_security_group_rule" "alb_http_inbound_from_internet" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  description       = "HTTP requests from internet for redirect"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_api_custom_alb_sg.id
}



resource "aws_security_group_rule" "alb_https_inbound_from_internet" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  description       = "Requests from internet"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_api_custom_alb_sg.id
}

resource "aws_security_group_rule" "public_alb_sg_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound on tcp"
  security_group_id = aws_security_group.public_api_custom_alb_sg.id
}
