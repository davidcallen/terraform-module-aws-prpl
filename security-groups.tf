# ---------------------------------------------------------------------------------------------------------------------
# Security Groups and Rules
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "prpl" {
  name        = local.name
  description = "prpl"
  vpc_id      = var.vpc.vpc_id
  tags = {
    Name            = local.name
    Application     = "prpl"
    ApplicationName = var.name_suffix
  }
}
resource "aws_security_group_rule" "prpl-allow-ingress-app-http" {
  type              = "ingress"
  description       = "http"
  from_port         = var.server_listening_port
  to_port           = var.server_listening_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ingress_cidrs.http
  security_group_id = aws_security_group.prpl.id
}
# All ingress to custom port 2022 (ssh)
resource "aws_security_group_rule" "prpl-allow-ingress-ssh" {
  type              = "ingress"
  description       = "ssh"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ingress_cidrs.ssh
  security_group_id = aws_security_group.prpl.id
}

# --------------------------------------- egress ------------------------------------------------------------------
resource "aws_security_group_rule" "prpl-allow-egress-app-http" {
  type              = "egress"
  description       = "http for the app"
  from_port         = var.server_listening_port
  to_port           = var.server_listening_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_egress_cidrs.http
  security_group_id = aws_security_group.prpl.id
}
resource "aws_security_group_rule" "prpl-allow-egress-ssh-to-workers" {
  type              = "egress"
  description       = "SSH to PRPL Worker Nodes"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_egress_cidrs.http
  security_group_id = aws_security_group.prpl.id
}
# For yum updates
resource "aws_security_group_rule" "prpl-allow-egress-http" {
  type              = "egress"
  description       = "http"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_egress_cidrs.http
  security_group_id = aws_security_group.prpl.id
}
resource "aws_security_group_rule" "prpl-allow-egress-https" {
  type              = "egress"
  description       = "https"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_egress_cidrs.https
  security_group_id = aws_security_group.prpl.id
}
resource "aws_security_group_rule" "prpl-allow-egress-telegraf-influxdb" {
  type              = "egress"
  description       = "telegraf agent to influxdb"
  from_port         = 8086
  to_port           = 8086
  protocol          = "tcp"
  cidr_blocks       = var.allowed_egress_cidrs.telegraf_influxdb
  security_group_id = aws_security_group.prpl.id
}
