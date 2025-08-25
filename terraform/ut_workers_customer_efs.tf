#######
# EFS #
#######
resource "aws_efs_file_system" "workers_customer_file_system" {
  #checkov:skip=CKV_AWS_184:KMS should be handle by the final customer
  creation_token = "workers-customer-efs"

  tags = {
    Name = "workers-customer-efs"
  }
}

resource "aws_efs_mount_target" "workers_customer_efs_mount_target" {
  for_each = toset(var.private_subnets_ids)

  file_system_id  = aws_efs_file_system.workers_customer_file_system.id
  subnet_id       = each.value
  security_groups = [aws_security_group.workers_customer_efs_sg.id]
}

##################
# Security Group #
##################
resource "aws_security_group" "workers_customer_efs_sg" {
  name        = "workers-customer-efs-sg"
  description = "Controls access to workers-customer efs"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ut_api_customer_to_efs_customer_rule" {
  type        = "ingress"
  from_port   = 2049
  to_port     = 2049
  protocol    = "tcp"
  description = "Requests from ut-api containers"

  source_security_group_id = aws_security_group.ut_api_customer_sg.id
  security_group_id        = aws_security_group.workers_customer_efs_sg.id
}

resource "aws_security_group_rule" "workers_customer_to_efs_customer_rule" {
  type        = "ingress"
  from_port   = 2049
  to_port     = 2049
  protocol    = "tcp"
  description = "Requests from workers-customer containers"

  source_security_group_id = aws_security_group.workers_customer_sg.id
  security_group_id        = aws_security_group.workers_customer_efs_sg.id
}

resource "aws_security_group_rule" "workers_customer_efs_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "tcp"
  description = "Allow outbound on tcp"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.workers_customer_efs_sg.id
}
