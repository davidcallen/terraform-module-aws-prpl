# ---------------------------------------------------------------------------------------------------------------------
# EFS filesystem for PRPL HOME DIR
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_efs_file_system" "prpl-home-efs" {
  count = (var.disk_prpl_home.enabled && var.disk_prpl_home.type == "EFS") ? 1 : 0
  # creation_token = "${local.name}-data"
  encrypted = var.disk_prpl_home.encrypted
  lifecycle {
    prevent_destroy = true # cant use var.environment.resource_deletion_protection
  }
  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name            = "${local.name}-data"
    Application     = "prpl"
    ApplicationName = var.name_suffix
  })
}

resource "aws_efs_mount_target" "prpl-home-efs" {
  count           = (var.disk_prpl_home.enabled && var.disk_prpl_home.type == "EFS") ? length(var.vpc.private_subnets_ids) : 0
  file_system_id  = aws_efs_file_system.prpl-home-efs[0].id
  subnet_id       = var.vpc.private_subnets_ids[count.index]
  security_groups = [aws_security_group.prpl-home-efs[0].id]
}

# Allow both ingress and egress for port 2049 (NFS) for our EC2 instances
# Restrict the traffic to within the VPC (and not outside).
resource "aws_security_group" "prpl-home-efs" {
  count       = (var.disk_prpl_home.enabled && var.disk_prpl_home.type == "EFS") ? 1 : 0
  name        = "${local.name}-efs"
  description = "Allows NFS traffic from instances within the VPC."
  vpc_id      = var.vpc.vpc_id
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = var.vpc.private_subnets_cidr_blocks
  }
  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = var.vpc.private_subnets_cidr_blocks
  }
  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name            = "${local.name}-efs"
    Application     = "prpl"
    ApplicationName = var.name_suffix
  })
}

