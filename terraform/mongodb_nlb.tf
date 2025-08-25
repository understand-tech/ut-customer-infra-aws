#######
# NLB #
#######
resource "aws_lb" "ut_mongodb" {
  name               = "ut-mongodb-nlb"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.ut_mongodb_nlb_sg.id]
  subnets            = var.public_subnets_ids

  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = true
}

resource "aws_lb_listener" "ut_mongodb_listener" {
  load_balancer_arn = aws_lb.ut_mongodb.arn
  port              = local.ut_mongodb_container_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ut_mongodb_target_group.arn
  }
}

resource "aws_lb_target_group" "ut_mongodb_target_group" {
  name        = "ut-mongodb-tg"
  port        = local.ut_mongodb_container_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
    protocol            = "TCP"
  }
}


######################
# NLB Security Group #
######################
resource "aws_security_group" "ut_mongodb_nlb_sg" {
  name        = "ut-mongodb-nlb-sg"
  description = "Controls access to ut mongodb NLB"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ut_api_to_mongodb_nlb_http_rule" {
  type        = "ingress"
  from_port   = local.ut_mongodb_container_port
  to_port     = local.ut_mongodb_container_port
  protocol    = "tcp"
  description = "Requests from ut-api containers"

  source_security_group_id = aws_security_group.ut_api_sg.id
  security_group_id        = aws_security_group.ut_mongodb_nlb_sg.id
}

resource "aws_security_group_rule" "ut_workers_to_mongodb_nlb_http_rule" {
  type        = "ingress"
  from_port   = local.ut_mongodb_container_port
  to_port     = local.ut_mongodb_container_port
  protocol    = "tcp"
  description = "Requests from ut-workers containers"

  source_security_group_id = aws_security_group.ut_workers_sg.id
  security_group_id        = aws_security_group.ut_mongodb_nlb_sg.id
}

resource "aws_security_group_rule" "ut_api_customer_to_mongodb_nlb_http_rule" {
  type        = "ingress"
  from_port   = local.ut_mongodb_container_port
  to_port     = local.ut_mongodb_container_port
  protocol    = "tcp"
  description = "Requests from ut-api-customer containers"

  source_security_group_id = aws_security_group.ut_api_customer_sg.id
  security_group_id        = aws_security_group.ut_mongodb_nlb_sg.id
}

resource "aws_security_group_rule" "ut_workers_customer_to_mongodb_nlb_http_rule" {
  type        = "ingress"
  from_port   = local.ut_mongodb_container_port
  to_port     = local.ut_mongodb_container_port
  protocol    = "tcp"
  description = "Requests from ut-workers-customer containers"

  source_security_group_id = aws_security_group.workers_customer_sg.id
  security_group_id        = aws_security_group.ut_mongodb_nlb_sg.id
}

resource "aws_security_group_rule" "ut_llm_to_mongodb_nlb_http_rule" {
  type        = "ingress"
  from_port   = local.ut_mongodb_container_port
  to_port     = local.ut_mongodb_container_port
  protocol    = "tcp"
  description = "Requests from ut-llm containers"

  source_security_group_id = aws_security_group.ut_llm_sg.id
  security_group_id        = aws_security_group.ut_mongodb_nlb_sg.id
}

resource "aws_security_group_rule" "ut_mongodb_nlb_sg_egress_rule" {
  type      = "egress"
  from_port = 0
  to_port   = 65535
  protocol  = "tcp"
  description = "Allow outbound on tcp"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_mongodb_nlb_sg.id
}
