locals {
  name_suffix                        = (length(var.name_suffix) == 0) ? "" : "-${var.name_suffix}"
  name                               = "${var.environment.resource_name_prefix}-prpl${local.name_suffix}"
  domain_host_name_short_ad_friendly = substr(join("", ["aws", md5(local.name)]), 0, 15)
}