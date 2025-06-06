#######
# ALB #
#######
resource "aws_lb" "ut_llm_alb" {
  name               = "ut-llm-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ut_llm_alb_sg.id]
  subnets            = var.private_subnets_ids

  enable_deletion_protection = true
}

resource "aws_lb_listener" "ut_llm_http_listener" {
  load_balancer_arn = aws_lb.ut_llm_alb.arn
  port              = local.ut_llm_elb_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ut_llm_target_group.arn
  }
}

resource "aws_lb_target_group" "ut_llm_target_group" {
  name        = "ut-llm-tg"
  port        = local.ut_llm_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    interval            = 30
    path                = "/health"
    port                = "traffic-port"
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 10
    matcher             = "200-299"
  }
}


######################
# ALB Security Group #
######################
resource "aws_security_group" "ut_llm_alb_sg" {
  name        = "ut-llm-alb-sg"
  description = "Controls access to the UT LLM ALB"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ut_api_to_llm_alb_rule" {
  type        = "ingress"
  from_port   = local.ut_llm_elb_port
  to_port     = local.ut_llm_elb_port
  protocol    = "tcp"
  description = "Requests from ut-api containers"

  source_security_group_id = aws_security_group.ut_api_sg.id
  security_group_id        = aws_security_group.ut_llm_alb_sg.id
}

resource "aws_security_group_rule" "ut_workers_to_llm_alb_rule" {
  type        = "ingress"
  from_port   = local.ut_llm_elb_port
  to_port     = local.ut_llm_elb_port
  protocol    = "tcp"
  description = "Requests from ut-workers containers"

  source_security_group_id = aws_security_group.ut_workers_sg.id
  security_group_id        = aws_security_group.ut_llm_alb_sg.id
}

resource "aws_security_group_rule" "llm_alb_sg_egress" {
  type      = "egress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_llm_alb_sg.id
}
