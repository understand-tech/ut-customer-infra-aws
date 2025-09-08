# Get lastest AWS provided AMI optimized for ECS cluster with GPU
data "aws_ssm_parameter" "ecs_gpu_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended"
}

locals {
  ecs_gpu_ami = jsondecode(data.aws_ssm_parameter.ecs_gpu_ami.value)
}


###################
# Launch template #
###################
resource "aws_launch_template" "ut_llm_template" {
  name_prefix = "ut-llm-instances-template"

  image_id               = local.ecs_gpu_ami.image_id
  instance_type          = var.llm_instance_type
  vpc_security_group_ids = [aws_security_group.ut_llm_ec2_sg.id]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 100
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.ut_llm_instance_profile.arn
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }

  user_data = filebase64("${path.module}/scripts/ecs_cluster/ecs_cluster.sh")
}


######################
# Auto Scaling group #
######################
resource "aws_autoscaling_group" "ut_llg_asg" {
  name                = "ut-llm-instance-asg"
  desired_capacity    = 1
  max_size            = 2
  min_size            = 0
  vpc_zone_identifier = var.private_subnets_ids

  health_check_grace_period = 30

  # Scale in management delegated to ECS.
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.ut_llm_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ut-llm-instance-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  # Prevent Terraform from interfering in scale process
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}


##################
# Security Group #
##################
resource "aws_security_group" "ut_llm_ec2_sg" {
  name        = "ut-llm-instances-sg"
  description = "Controls access to UT LLM instances"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ut_llm_ec2_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  description = "Outbound"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_llm_ec2_sg.id
}


############
# IAM Role #
############
resource "aws_iam_instance_profile" "ut_llm_instance_profile" {
  name = "ut-llm-instance-profile"
  role = aws_iam_role.ut_llm_instance_role.name
}

resource "aws_iam_role" "ut_llm_instance_role" {
  name               = "ut-llm-instance-role"
  path               = "/service-role/ec2/"
  assume_role_policy = data.aws_iam_policy_document.ut_llm_instance_role_trust.json
}

data "aws_iam_policy_document" "ut_llm_instance_role_trust" {
  statement {
    sid = "AllowEc2"

    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "ecs.amazonaws.com"
      ]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values = [
        var.aws_account_id
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ut_llm_instance_ecs_policy_att" {
  role       = aws_iam_role.ut_llm_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ut_llm_instance_ssm_policy_att" {
  role       = aws_iam_role.ut_llm_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


#########################
# ECS Capacity Provider #
#########################
resource "aws_ecs_capacity_provider" "ut_llm_capacity_provider" {
  name = "ut-llm-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ut_llg_asg.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "ut_llm_capacity_provider" {
  cluster_name       = aws_ecs_cluster.ut_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.ut_llm_capacity_provider.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ut_llm_capacity_provider.name
    base              = 1
    weight            = 100
  }
}
