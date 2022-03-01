# ---------------------------------------------------------------------------------------------------------------------
# Application Load Balancers
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # Attempts to adhere to AWS requirement of a unique TargetGroup name that is less than 32 chars
  aws_lb_target_group_base_name = ((var.ha_auto_scaling_group.target_group_name_prefix == "")
    ? local.asg_name
    : var.ha_auto_scaling_group.target_group_name_prefix
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# SSL certificate for use on Load Balancer HTTPS listener
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_acm_certificate" "prpl-amazon-provider" {
  count = (var.ha_high_availability_enabled && (
    (var.ha_public_load_balancer.enabled && var.ha_public_load_balancer.ssl_cert.use_amazon_provider)
    || (var.ha_private_load_balancer.enabled && var.ha_private_load_balancer.ssl_cert.use_amazon_provider))
  ) ? 1 : 0
  domain_name       = var.hostname_fqdn
  validation_method = "DNS"
  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name            = "${local.name}-alb-public"
    Application     = "prpl"
    ApplicationName = var.name_suffix
  })
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Application Load Balancers : Public
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # Check that name does not exceed 32 chars and does not end in hyphen (aws enforced restrictions)
  aws_lb_target_group_public_base_name = ((var.ha_auto_scaling_group.target_group_name_prefix == "")
    ? "${local.aws_lb_target_group_base_name}-public"
    : "${var.ha_auto_scaling_group.target_group_name_prefix}-pub"
  )
}
resource "aws_lb_listener_certificate" "prpl-public" {
  count           = (var.ha_high_availability_enabled && var.ha_public_load_balancer.enabled) ? 1 : 0
  listener_arn    = var.ha_public_load_balancer.alb_listener_arn
  certificate_arn = aws_acm_certificate.prpl-amazon-provider[0].arn
}
# Note that the aws_lb_listener is defined outside this module and shared with others
resource "aws_lb_listener_rule" "prpl-public-https" {
  count        = (var.ha_high_availability_enabled && var.ha_public_load_balancer.enabled) ? 1 : 0
  listener_arn = var.ha_public_load_balancer.alb_listener_arn
  priority     = var.ha_public_load_balancer.alb_listener_priority
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prpl-public-https[count.index].arn
  }
  condition {
    host_header {
      values = [var.hostname_fqdn]
    }
  }
}
locals {
  # Check that name does not exceed 32 chars and does not end in hyphen (aws enforced restrictions)
  aws_lb_target_group_public_truncated_names_https = ((substr("${local.aws_lb_target_group_public_base_name}-https", 30, 31) == "-")
    ? substr("${local.aws_lb_target_group_public_base_name}-https", 0, 30)
    : substr("${local.aws_lb_target_group_public_base_name}-https", 0, 31)
  )
}
resource "aws_lb_target_group" "prpl-public-https" {
  count                = (var.ha_high_availability_enabled && var.ha_public_load_balancer.enabled) ? 1 : 0
  name                 = local.aws_lb_target_group_public_truncated_names_https
  target_type          = "instance"
  port                 = var.server_listening_port
  protocol             = "HTTP"
  vpc_id               = var.vpc.vpc_id
  deregistration_delay = 0
  health_check {
    healthy_threshold   = 8
    unhealthy_threshold = 8
    interval            = 30
    protocol            = "HTTP"
    path                = "/"
    port                = var.server_listening_port
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Application Load Balancers : Private
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # Check that name does not exceed 32 chars and does not end in hyphen (aws enforced restrictions)
  aws_lb_target_group_private_base_name = ((var.ha_auto_scaling_group.target_group_name_prefix == "")
    ? "${local.aws_lb_target_group_base_name}-private"
    : "${var.ha_auto_scaling_group.target_group_name_prefix}-priv"
  )
}
resource "aws_lb_listener_certificate" "prpl-private" {
  count = (var.ha_high_availability_enabled && var.ha_private_load_balancer.enabled) ? 1 : 0

  listener_arn    = var.ha_private_load_balancer.alb_listener_arn
  certificate_arn = aws_acm_certificate.prpl-amazon-provider[0].arn
}
# Note that the aws_lb_listener is defined outside this module and shared with others
resource "aws_lb_listener_rule" "prpl-private-https" {
  count = (var.ha_high_availability_enabled && var.ha_private_load_balancer.enabled) ? 1 : 0

  listener_arn = var.ha_private_load_balancer.alb_listener_arn
  priority     = var.ha_private_load_balancer.alb_listener_priority
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prpl-private-https[count.index].arn
  }
  condition {
    host_header {
      values = [var.hostname_fqdn]
    }
  }
}
locals {
  # Check that name does not exceed 32 chars and does not end in hyphen (aws enforced restrictions)
  aws_lb_target_group_private_truncated_names_https = ((substr("${local.aws_lb_target_group_private_base_name}-https", 30, 31) == "-")
    ? substr("${local.aws_lb_target_group_private_base_name}-https", 0, 30)
    : substr("${local.aws_lb_target_group_private_base_name}-https", 0, 31)
  )
}
resource "aws_lb_target_group" "prpl-private-https" {
  count = (var.ha_high_availability_enabled && var.ha_private_load_balancer.enabled) ? 1 : 0

  name                 = local.aws_lb_target_group_private_truncated_names_https
  target_type          = "instance"
  port                 = var.server_listening_port
  protocol             = "HTTP"
  vpc_id               = var.vpc.vpc_id
  deregistration_delay = 0
  health_check {
    healthy_threshold   = 8
    unhealthy_threshold = 8
    interval            = 30
    protocol            = "HTTP"
    path                = "/"
    port                = var.server_listening_port
  }
}
