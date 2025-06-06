#################
# Redis cluster #
#################
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "ut-redis-cluster"
  engine               = "redis"
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"

  # Compute
  node_type       = var.redis_node_type
  num_cache_nodes = 1

  # Network
  subnet_group_name  = aws_elasticache_subnet_group.redis_subnets.name
  security_group_ids = [aws_security_group.ut_redis_sg.id]
  port               = local.ut_redis_port

  # Maintenance
  maintenance_window       = var.redis_maintenance_window
  snapshot_window          = var.redis_snapshot_window
  snapshot_retention_limit = var.redis_backup_retention
}


################
# Subnet group #
################
resource "aws_elasticache_subnet_group" "redis_subnets" {
  name       = "ut-redis-cluster-subnets"
  subnet_ids = var.private_subnets_ids
}


########################
# Redis Security Group #
########################
resource "aws_security_group" "ut_redis_sg" {
  name        = "ut-redis-cluster-sg"
  description = "Controls access to ut redis cluster"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ut_api_to_ut_redis_rule" {
  type        = "ingress"
  from_port   = local.ut_redis_port
  to_port     = local.ut_redis_port
  protocol    = "tcp"
  description = "Requests from ut-api containers"

  source_security_group_id = aws_security_group.ut_api_sg.id
  security_group_id        = aws_security_group.ut_redis_sg.id
}

resource "aws_security_group_rule" "ut_workers_to_ut_redis_rule" {
  type        = "ingress"
  from_port   = local.ut_redis_port
  to_port     = local.ut_redis_port
  protocol    = "tcp"
  description = "Requests from ut-workers containers"

  source_security_group_id = aws_security_group.ut_workers_sg.id
  security_group_id        = aws_security_group.ut_redis_sg.id
}

resource "aws_security_group_rule" "ut_redis_outbound_rule" {
  type      = "egress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ut_redis_sg.id
}
