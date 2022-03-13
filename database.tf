# ---------------------------------------------------------------------------------------------------------------------
# MariaDB database in RDS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_db_instance" "prpl" {
  count          = (var.database.type == "RDS") ? 1 : 0
  identifier     = local.name
  engine         = var.database.engine
  engine_version = var.database.engine_version
  instance_class = var.database.aws_instance_type # t3 is 2 vCPU, t2 is 1 vCPU
  multi_az       = var.ha_high_availability_enabled
  username       = "PRPL_ROOT"                     # Username of root user
  password       = var.database.db_master_password # Password of root user

  # parameter_group_name = "default.mysql5.7"
  allocated_storage       = 10
  storage_type            = "gp2"
  max_allocated_storage   = 100 # Enable auto scaling of storage up to this value (in GBytes)
  storage_encrypted       = true
  vpc_security_group_ids  = [aws_security_group.prpl-data-db[0].id]
  db_subnet_group_name    = (var.database.type == "RDS") ? aws_db_subnet_group.prpl[0].name : ""
  backup_retention_period = var.backups.rds.retention_period
  backup_window           = var.backups.rds.window
  # TODO : when upgrade Terraform AWS Provider see if we can use "delete_automated_backups"
  #  delete_automated_backups  = var.backups.rds.delete_automated_backups
  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name               = local.name
    UsedByInstanceName = local.name
    Visibility         = "private"
    Application        = "prpl"
    ApplicationName    = var.name_suffix
  })
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"] # ["alert", "audit", "error", "general", "listener", "slowquery", "trace"]
  # monitoring_role_arn       = var.database.db_cloudwatch_role_arn
  # monitoring_interval       = 0         # disable enhanced monitoring of metrics to CloudWatch

  skip_final_snapshot       = true # dont try and take a final snapshot when deleting RDS instance
  final_snapshot_identifier = local.name
  deletion_protection       = var.environment.resource_deletion_protection
  apply_immediately         = true # May need to change this if want changes to occur in scheduled maintenance window instead of immediate
}

resource "aws_db_subnet_group" "prpl" {
  count      = (var.database.type == "RDS") ? 1 : 0
  name       = local.name
  subnet_ids = [var.vpc.private_subnets_ids[0], var.vpc.private_subnets_ids[1]]
  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name            = local.name
    Visibility      = "private"
    Application     = "prpl"
    ApplicationName = var.name_suffix
  })
}

# Allow both ingress and egress for port 3306 (mysql/mariadb) for our EC2 instances
# Restrict the traffic to within the VPC (and not outside).
resource "aws_security_group" "prpl-data-db" {
  count       = (var.database.type == "RDS") ? 1 : 0
  name        = "${local.name}-db"
  description = "Allows MariaDB/MySQL traffic between RDS and EC2 instances within the VPC."
  vpc_id      = var.vpc.vpc_id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.database.allowed_ingress_cidrs
  }
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.database.allowed_ingress_cidrs
  }
  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name            = "${local.name}-db"
    Application     = "prpl"
    ApplicationName = var.name_suffix
  })
}
