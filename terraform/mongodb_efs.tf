#######
# EFS #
#######
resource "aws_efs_file_system" "ut_mongodb_file_system" {
  creation_token = "mongodb-efs"

  tags = {
    Name = "mongodb-efs"
  }
}

resource "aws_efs_mount_target" "ut_mongodb_efs_mount_target" {
  for_each = toset(var.private_subnets_ids)

  file_system_id  = aws_efs_file_system.ut_mongodb_file_system.id
  subnet_id       = each.value
  security_groups = [aws_security_group.ut_mongodb_efs_sg.id]
}


##################
# Security Group #
##################
resource "aws_security_group" "ut_mongodb_efs_sg" {
  name        = "ut-mongodb-efs-sg"
  description = "Controls access to ut mongodb efs"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ut_mongodb_to_efs_rule" {
  type        = "ingress"
  from_port   = local.ut_efs_port
  to_port     = local.ut_efs_port
  protocol    = "tcp"
  description = "Requests from ut-mongodb containers"

  source_security_group_id = aws_security_group.ut_mongodb_sg.id
  security_group_id        = aws_security_group.ut_mongodb_efs_sg.id
}
