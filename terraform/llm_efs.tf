#######
# EFS #
#######
resource "aws_efs_file_system" "ut_llm_models_file_system" {
  #checkov:skip=CKV_AWS_184:KMS should be handle by the final customer
  creation_token = "ut-llm-models-efs"

  tags = {
    Name = "ut-llm-models-efs"
  }
}

resource "aws_efs_mount_target" "ut_llm_models_efs_mount_target" {
  for_each = toset(var.private_subnets_ids)

  file_system_id  = aws_efs_file_system.ut_llm_models_file_system.id
  subnet_id       = each.value
  security_groups = [aws_security_group.ut_llm_efs_sg.id]
}

resource "aws_efs_file_system" "ut_llm_ollama_file_system" {
  #checkov:skip=CKV_AWS_184:KMS should be handle by the final customer
  creation_token = "ut-llm-ollama-efs"

  tags = {
    Name = "ut-llm-ollama-efs"
  }
}

resource "aws_efs_mount_target" "ut_llm_ollama_efs_mount_target" {
  for_each = toset(var.private_subnets_ids)

  file_system_id  = aws_efs_file_system.ut_llm_ollama_file_system.id
  subnet_id       = each.value
  security_groups = [aws_security_group.ut_llm_efs_sg.id]
}


##################
# Security Group #
##################
resource "aws_security_group" "ut_llm_efs_sg" {
  name        = "ut-llm-efs-sg"
  description = "Controls access to ut llm efs"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ut_llm_task_to_efs_rule" {
  type        = "ingress"
  from_port   = local.ut_efs_port
  to_port     = local.ut_efs_port
  protocol    = "tcp"
  description = "Requests from ut-llm containers"

  source_security_group_id = aws_security_group.ut_llm_sg.id
  security_group_id        = aws_security_group.ut_llm_efs_sg.id
}

resource "aws_security_group_rule" "ut_llm_instance_to_efs_rule" {
  type        = "ingress"
  from_port   = local.ut_efs_port
  to_port     = local.ut_efs_port
  protocol    = "tcp"
  description = "Requests from ut-llm instances"

  source_security_group_id = aws_security_group.ut_llm_ec2_sg.id
  security_group_id        = aws_security_group.ut_llm_efs_sg.id
}

resource "aws_security_group_rule" "ut_llm_efs_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  description = "Outbound"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_llm_efs_sg.id
}
