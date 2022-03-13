# ---------------------------------------------------------------------------------------------------------------------
# Backups for EFS data files
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_backup_vault" "prpl" {
  count       = (length(var.backups.plans) > 0) ? 1 : 0

  name        = local.name
  # Currently using default AWS Managed key "aws/backup"
  #  kms_key_arn = "${aws_kms_key.example.arn}"
  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name            = local.name
    Application     = "prpl"
    ApplicationName = var.name_suffix
  })
  lifecycle {
    prevent_destroy = true         # cant use var.environment.resource_deletion_protection
  }
}

resource "aws_backup_plan" "prpl" {
  count       = (length(var.backups.plans) > 0) ? length(var.backups.plans)  : 0

  name        = "${local.name}-${var.backups.plans[count.index].name}"
  rule {
    rule_name         = local.name
    target_vault_name = aws_backup_vault.prpl[0].name
    schedule          = var.backups.plans[count.index].schedule
    start_window      = var.backups.plans[count.index].start_window
    completion_window = var.backups.plans[count.index].completion_window
    lifecycle {
      cold_storage_after = var.backups.plans[count.index].lifecycle.cold_storage_after
      delete_after       = var.backups.plans[count.index].lifecycle.delete_after
    }
  }
  tags = merge(var.global_default_tags, var.environment.default_tags, {
    Name            = "${local.name}-${var.backups.plans[count.index].name}"
    Application     = "prpl"
    ApplicationName = var.name_suffix
  })
}

# Backups for EFS
resource "aws_backup_selection" "prpl" {
  count       = (var.disk_prpl_home.type == "EFS" && length(var.backups.plans) > 0) ? length(var.backups.plans) : 0

  iam_role_arn = var.backups.backup_role_arn
  name         = local.name
  plan_id      = aws_backup_plan.prpl[count.index].id
  resources = [
    aws_efs_file_system.prpl-home-efs[0].arn
  ]
}

# Backups for EBS
resource "aws_backup_selection" "prpl-ebs" {
  count       = (var.disk_prpl_home.type == "EBS" && length(var.backups.plans) > 0) ? length(var.backups.plans) : 0

  iam_role_arn = var.backups.backup_role_arn
  name         = "${local.name}-ebs-data"
  plan_id      = aws_backup_plan.prpl[count.index].id
  resources = [
    aws_ebs_volume.prpl-data-ebs[0].arn
  ]
}