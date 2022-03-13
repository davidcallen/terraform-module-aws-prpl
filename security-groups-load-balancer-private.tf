# ---------------------------------------------------------------------------------------------------------------------
# Security Groups for Private App Load Balancer
# ---------------------------------------------------------------------------------------------------------------------

# Only need to allow egress for HTTPS on var.server_listening_port for ALB health checks to work
resource "aws_security_group_rule" "prpl-alb-private-allow-egress-http-internal" {
  count             = (var.ha_high_availability_enabled && var.ha_private_load_balancer.enabled && var.ha_private_load_balancer.port != var.server_listening_port) ? 1 : 0
  type              = "egress"
  description       = "http internal for access from ALB"
  from_port         = var.server_listening_port
  to_port           = var.server_listening_port
  protocol          = "tcp"
  cidr_blocks       = var.vpc.private_subnets_cidr_blocks
  security_group_id = var.ha_private_load_balancer.security_group_id
}
