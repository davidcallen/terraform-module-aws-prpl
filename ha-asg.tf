# ---------------------------------------------------------------------------------------------------------------------
# HighAvailablity/Failover AutoScalingGroup for PRPL
# ---------------------------------------------------------------------------------------------------------------------
locals {
  target_group_arns = (var.ha_high_availability_enabled) ? concat((var.ha_public_load_balancer.arn != "") ? [aws_lb_target_group.prpl-public-https[0].arn] : [], (var.ha_private_load_balancer.arn != "") ? [aws_lb_target_group.prpl-private-https[0].arn] : []) : []
  asg_name          = (var.ha_high_availability_enabled) ? local.name : ""
}
resource "aws_autoscaling_group" "prpl" {
  count                     = (var.ha_high_availability_enabled) ? 1 : 0
  name                      = local.asg_name
  target_group_arns         = local.target_group_arns
  max_size                  = var.ha_auto_scaling_group.max_size
  min_size                  = var.ha_auto_scaling_group.min_size
  desired_capacity          = var.ha_auto_scaling_group.desired_capacity
  health_check_grace_period = var.ha_auto_scaling_group.health_check_grace_period
  health_check_type         = "ELB"
  force_delete              = false
  # placement_group           = "${aws_placement_group.test.id}"
  launch_configuration = aws_launch_configuration.prpl[0].name
  vpc_zone_identifier  = var.vpc.private_subnets_ids
  default_cooldown     = var.ha_auto_scaling_group.default_cooldown # Start the failover instance quickly
  termination_policies = ["OldestInstance"]
  suspended_processes  = var.ha_auto_scaling_group.suspended_processes
  tag {
    key                 = "Name"
    value               = local.asg_name
    propagate_at_launch = true
  }
  depends_on = [aws_efs_mount_target.prpl-home-efs, aws_efs_file_system.prpl-home-efs, aws_db_instance.prpl]
}

// Currently dont want autoscaling - just the single instance. This simplifies any issues could have with multi-writers connected to same EFS storage.
//
//resource "aws_autoscaling_policy" "ta-website" {
//  count                       = (var.ha_high_availability_enabled) ? 1 : 0
//
//  name                        = "${local.asg_name}-scaling-policy"
//  autoscaling_group_name      = aws_autoscaling_group.ta-website[0].name
//  policy_type                 = "TargetTrackingScaling"
//  estimated_instance_warmup   = 60
//  target_tracking_configuration {
//    predefined_metric_specification {
//      predefined_metric_type  = "ALBRequestCountPerTarget"
//      # resource_label e.g.  "app/ta-core-public-alb-public/cf95e10757d54ca5/targetgroup/ta-core-public-prod-public-https/cc0f418b5616e43f"
//      resource_label          = "${var.ha_public_load_balancer.arn_suffix}/${aws_lb_target_group.ta-website-public-https[0].arn_suffix}"
//    }
//    target_value              = 50
//    disable_scale_in          = false
//  }
//}

locals {
  vpc_security_group_ids_storage = (var.disk_prpl_home.enabled && var.disk_prpl_home.type == "EFS") ? [aws_security_group.prpl-home-efs[0].id] : []
  vpc_security_group_ids         = concat([aws_security_group.prpl.id], local.vpc_security_group_ids_storage)
}
# TODO : Consider change from aws_launch_configuration to the newer aws_launch_template
resource "aws_launch_configuration" "prpl" {
  count                = (var.ha_high_availability_enabled) ? 1 : 0
  name_prefix          = "${local.asg_name}-"
  image_id             = var.aws_ami_id
  instance_type        = var.aws_instance_type
  iam_instance_profile = var.iam_instance_profile
  security_groups      = local.vpc_security_group_ids
  key_name             = var.aws_ssh_key_name
  root_block_device {
    delete_on_termination = true
    encrypted             = var.disk_root.encrypted
  }
  user_data = templatefile("${path.module}/user-data.yaml", {
    aws_region                        = var.aws_region,
    aws_zones                         = join(" ", var.aws_zones[*]),
    aws_ec2_instance_name             = local.name
    aws_ec2_instance_hostname_fqdn    = var.hostname_fqdn
    route53_enabled                   = var.route53_enabled ? "TRUE" : "FALSE"
    route53_direct_dns_update_enabled = var.route53_direct_dns_update_enabled ? "TRUE" : "FALSE"
    route53_private_hosted_zone_id    = var.route53_private_hosted_zone_id

    domain_host_name_short_ad_friendly = local.domain_host_name_short_ad_friendly
    domain_name                        = var.domain_name
    domain_realm_name                  = upper(var.domain_name)
    domain_netbios_name                = var.domain_netbios_name
    domain_join_user_name              = var.domain_join_user_name
    domain_join_user_password          = var.domain_join_user_password
    domain_login_allowed_groups        = join(",", var.domain_login_allowed_groups[*])
    domain_login_allowed_users         = join(",", var.domain_login_allowed_users[*])

    aws_efs_id                 = (var.disk_prpl_home.enabled && var.disk_prpl_home.type == "EFS") ? aws_efs_file_system.prpl-home-efs[0].id : ""
    ebs_device_name            = (var.disk_prpl_home.enabled && var.disk_prpl_home.type == "EBS") ? "/dev/nvme1n1" : ""
    aws_asg_name               = local.asg_name
    check_efs_asg_max_attempts = var.ha_auto_scaling_group.check_efs_asg_max_attempts
    prpl_linux_user_name       = var.prpl_linux_user_name
    prpl_linux_user_group      = var.prpl_linux_user_group
    prpl_user_ssh_public_key   = var.prpl_user_ssh_public_key
    // prpl_config_s3_bucket_name                = aws_s3_bucket.prpl-config-files.bucket
    prpl_db_admin_user_password_secret_id        = var.prpl_db_admin_user_password_secret_id
    prpl_admin_user_password_secret_id           = var.prpl_admin_user_password_secret_id
    db_hostname                                  = (var.database.type == "RDS") ? aws_db_instance.prpl[0].endpoint : var.database.db_hostname
    db_prpl_database_name                        = var.database.db_prpl_database_name
    db_prpl_username                             = var.database.db_prpl_username
    db_prpl_password_secret_id                   = var.database.db_prpl_password_secret_id
    cloudwatch_enabled                           = var.cloudwatch_enabled ? "TRUE" : "FALSE"
    cloudwatch_refresh_interval_secs             = var.cloudwatch_refresh_interval_secs
    telegraf_enabled                             = var.telegraf_enabled ? "TRUE" : "FALSE"
    telegraf_influxdb_url                        = var.telegraf_influxdb_url
    telegraf_influxdb_password_secret_id         = var.telegraf_influxdb_password_secret_id
    telegraf_influxdb_retention_policy           = var.telegraf_influxdb_retention_policy
    telegraf_influxdb_https_insecure_skip_verify = var.telegraf_influxdb_https_insecure_skip_verify
  })
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_efs_mount_target.prpl-home-efs, aws_efs_file_system.prpl-home-efs] # , aws_s3_bucket_object.prpl-config-files-upload]
}
resource "aws_autoscaling_notification" "prpl" {
  count       = (var.ha_high_availability_enabled) ? 1 : 0
  group_names = [aws_autoscaling_group.prpl[0].name]
  notifications = [
    //    "autoscaling:EC2_INSTANCE_LAUNCH",
    //    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
  topic_arn = ((var.ha_auto_scaling_group.cloudwatch_alarm_sns_topic_arn == "")
    ? var.cloudwatch_alarm_default_sns_topic_arn
    : var.ha_auto_scaling_group.cloudwatch_alarm_sns_topic_arn
  )
}
