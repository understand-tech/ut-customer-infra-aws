#######
# EFS #
#######
resource "aws_efs_file_system" "ut_workers_file_system" {
  #checkov:skip=CKV_AWS_184:KMS should be handle by the final customer
  creation_token = "ut-workers-efs"

  tags = {
    Name = "ut-workers-efs"
  }
}

resource "aws_efs_mount_target" "ut_workers_efs_mount_target" {
  for_each = toset(var.private_subnets_ids)

  file_system_id  = aws_efs_file_system.ut_workers_file_system.id
  subnet_id       = each.value
  security_groups = [aws_security_group.ut_workers_efs_sg.id]
}


##################
# Security Group #
##################
resource "aws_security_group" "ut_workers_efs_sg" {
  name        = "ut-workers-efs-sg"
  description = "Controls access to ut-workers efs"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ut_api_to_efs_rule" {
  type        = "ingress"
  from_port   = local.ut_efs_port
  to_port     = local.ut_efs_port
  protocol    = "tcp"
  description = "Requests from ut-api containers"

  source_security_group_id = aws_security_group.ut_api_sg.id
  security_group_id        = aws_security_group.ut_workers_efs_sg.id
}

resource "aws_security_group_rule" "ut_workers_to_efs_rule" {
  type        = "ingress"
  from_port   = local.ut_efs_port
  to_port     = local.ut_efs_port
  protocol    = "tcp"
  description = "Requests from ut-workers containers"

  source_security_group_id = aws_security_group.ut_workers_sg.id
  security_group_id        = aws_security_group.ut_workers_efs_sg.id
}

resource "aws_security_group_rule" "ut_workers_efs_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  description = "Outbound"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_workers_efs_sg.id
}
