# ---------------------------------------------------------------------------------------------------------------------
# High-Availability/Failover - Application Load Balancer
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
locals {
  https_cert_domain_validation_options = (var.route53_enabled && var.ha_high_availability_enabled && (
    (var.ha_public_load_balancer.enabled && var.ha_public_load_balancer.ssl_cert.use_amazon_provider)
    || (var.ha_private_load_balancer.enabled && var.ha_private_load_balancer.ssl_cert.use_amazon_provider))
  ) ? aws_acm_certificate.prpl-amazon-provider[0].domain_validation_options : []
}
resource "aws_route53_record" "prpl-amazon-provider-https-cert-validation" {
  for_each = {
    # for dvo in aws_acm_certificate.prpl-amazon-provider.domain_validation_options : dvo.domain_name => {
    for dvo in local.https_cert_domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_public_hosted_zone_id
}
resource "aws_acm_certificate_validation" "prpl-amazon-provider" {
  count = (var.route53_enabled && var.ha_high_availability_enabled && (
    (var.ha_public_load_balancer.enabled && var.ha_public_load_balancer.ssl_cert.use_amazon_provider)
    || (var.ha_private_load_balancer.enabled && var.ha_private_load_balancer.ssl_cert.use_amazon_provider))
  ) ? 1 : 0
  certificate_arn         = aws_acm_certificate.prpl-amazon-provider[0].arn
  validation_record_fqdns = [for record in aws_route53_record.prpl-amazon-provider-https-cert-validation : record.fqdn]
}

# ---------------------------------------------------------------------------------------------------------------------
# Route53 DNS for the Load Balancers
# ---------------------------------------------------------------------------------------------------------------------
data "aws_alb" "application-load-balancer-public" {
  count = (var.ha_high_availability_enabled && var.ha_public_load_balancer.enabled) ? 1 : 0
  arn   = var.ha_public_load_balancer.arn
}
resource "aws_route53_record" "prpl-amazon-provider-public-dns" {
  count           = (var.route53_enabled && var.ha_high_availability_enabled && var.ha_public_load_balancer.enabled) ? 1 : 0
  allow_overwrite = true
  name            = var.ha_public_load_balancer.hostname_fqdn
  records         = [data.aws_alb.application-load-balancer-public[0].dns_name]
  ttl             = 60
  type            = "CNAME"
  zone_id         = var.route53_public_hosted_zone_id
}
# If Public ALB and no Private ALB then use Public ALB DNS on the PrivateHZ (otherwise DNS resolution will fail)
resource "aws_route53_record" "prpl-amazon-provider-private-dns-for-public-alb" {
  count = (var.route53_enabled && var.ha_high_availability_enabled
    && var.ha_public_load_balancer.enabled
    && var.ha_private_load_balancer.enabled == false
  ) ? 1 : 0
  allow_overwrite = true
  name            = var.ha_public_load_balancer.hostname_fqdn
  records         = [data.aws_alb.application-load-balancer-public[0].dns_name]
  ttl             = 60
  type            = "CNAME"
  zone_id         = var.route53_private_hosted_zone_id
}
# For Private ALB
data "aws_alb" "application-load-balancer-private" {
  count = (var.route53_enabled && var.ha_high_availability_enabled && var.ha_private_load_balancer.enabled) ? 1 : 0
  arn   = var.ha_private_load_balancer.arn
}
resource "aws_route53_record" "prpl-amazon-provider-private-dns-for-private-alb" {
  count           = (var.route53_enabled && var.ha_high_availability_enabled && var.ha_private_load_balancer.enabled) ? 1 : 0
  allow_overwrite = true
  name            = var.ha_private_load_balancer.hostname_fqdn
  records         = [data.aws_alb.application-load-balancer-private[0].dns_name]
  ttl             = 60
  type            = "CNAME"
  zone_id         = var.route53_private_hosted_zone_id
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
  protocol             = "HTTPS"
  vpc_id               = var.vpc.vpc_id
  deregistration_delay = 0
  health_check {
    healthy_threshold   = 8
    unhealthy_threshold = 8
    interval            = 30
    protocol            = "HTTP"
    path                = "/health"
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
  protocol             = "HTTPS"
  vpc_id               = var.vpc.vpc_id
  deregistration_delay = 0
  health_check {
    healthy_threshold   = 8
    unhealthy_threshold = 8
    interval            = 30
    protocol            = "HTTP"
    path                = "/health"
    port                = var.server_listening_port
  }
}
