# ---------------------------------------------------------------------------------------------------------------------
# Deploy an EC2 instance for PRPL  (centos7-based image), with no high-availabity setup
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "prpl" {
  count                  = (var.ha_high_availability_enabled == false) ? 1 : 0
  ami                    = var.aws_ami_id
  instance_type          = var.aws_instance_type
  iam_instance_profile   = var.iam_instance_profile
  subnet_id              = var.vpc.private_subnets_ids[0]
  vpc_security_group_ids = local.vpc_security_group_ids
  key_name               = var.aws_ssh_key_name
  root_block_device {
    delete_on_termination = true
    encrypted             = var.disk_root.encrypted
  }
  disable_api_termination = var.environment.resource_deletion_protection
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
    aws_asg_name               = ""
    check_efs_asg_max_attempts = var.ha_auto_scaling_group.check_efs_asg_max_attempts
    prpl_linux_user_name       = var.prpl_linux_user_name
    prpl_linux_user_group      = var.prpl_linux_user_group
    prpl_user_ssh_public_key   = var.prpl_user_ssh_public_key
    // prpl_config_s3_bucket_name                   = aws_s3_bucket.prpl-config-files.bucket
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
  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name            = local.name
    Zone            = var.aws_zones[0]
    Visibility      = "private"
    Application     = "prpl"
    ApplicationName = var.name_suffix
  })
  depends_on = [aws_efs_mount_target.prpl-home-efs, aws_efs_file_system.prpl-home-efs, aws_db_instance.prpl] # , aws_s3_bucket_object.prpl-config-files-upload]
}
