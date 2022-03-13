resource "aws_ebs_volume" "prpl-data-ebs" {
  count             = (var.ha_high_availability_enabled == false && var.disk_prpl_home.enabled == false && var.disk_prpl_home.type == "EBS") ? 1 : 0
  availability_zone = var.aws_zones[0]
  size              = var.disk_prpl_home.size
  encrypted         = var.disk_prpl_home.encrypted

  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name            = "${local.name}-data"
    Zone            = var.aws_zones[0]
    Visibility      = "private"
    Application     = "prpl"
    ApplicationName = var.name_suffix
  })
}

resource "aws_volume_attachment" "prpl-data-ebs" {
  count       = (var.ha_high_availability_enabled == false && var.disk_prpl_home.enabled == false && var.disk_prpl_home.type == "EBS") ? 1 : 0
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.prpl-data-ebs[0].id
  instance_id = (var.ha_high_availability_enabled == false) ? aws_instance.prpl[0].id : ""
}
