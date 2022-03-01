variable "aws_region" {
  description = "AWS region to apply terraform to."
  default     = "eu-west-1"
  type        = string
}
variable "aws_zones" {
  description = "AWS zones to apply terraform to. The first zone in the list will be the default for single AZ requirements."
  default     = ["eu-west-1a", "eu-west-1b"]
  type        = list(string)
}
variable "org_short_name" {
  description = "Short name for organisation"
  default     = ""
  type        = string
}
variable "org_domain_name" {
  description = "Domain name for organisation"
  default     = ""
  type        = string
}
variable "name" {
  description = "Name of the server that will be deployed"
  default     = "prpl"
  type        = string
}
variable "hostname_fqdn" {
  description = "FQDN Name of the server that will be deployed"
  default     = ""
  type        = string
}
variable "route53_enabled" {
  description = "If using Route53 for DNS resolution"
  default     = false
  type        = bool
}
variable "route53_direct_dns_update_enabled" {
  description = "If using direct add/update of hostname DNS record to Route53"
  default     = false
  type        = bool
}
variable "route53_private_hosted_zone_id" {
  description = "Route53 Private Hosted Zone ID (if in use)."
  default     = ""
  type        = string
}
variable "environment" {
  description = "Environment information e.g. account IDs, public/private subnet cidrs"
  type = object({
    name = string
    # Environment Account IDs are used for giving permissions to those Accounts for resources such as AMIs
    account_id = string
    # These cidrs are needed to setup SecurityGroup rules, and routes for cross-account access.
    cidr_block                  = string
    private_subnets_cidr_blocks = list(string)
    public_subnets_cidr_blocks  = list(string)
    resource_name_prefix        = string
    # For some environments  (e.g. Core, Customer/production) want to protect against accidental deletion of resources
    resource_deletion_protection = bool
    default_tags                 = map(string)
  })
  default = {
    name                         = ""
    account_id                   = ""
    cidr_block                   = ""
    private_subnets_cidr_blocks  = []
    public_subnets_cidr_blocks   = []
    resource_name_prefix         = ""
    resource_deletion_protection = true
    default_tags                 = {}
  }
}
variable "vpc" {
  description = "VPC information. These are inputs to the VPC module github.com/terraform-aws-modules/terraform-aws-vpc.git"
  type = object({
    vpc_id = string
    # VPC cidr block. Must not overlap with other VPCs in this aws account or others within our organisation.
    cidr_block = string
    # List of VPC private subnet cidr blocks. Must not overlap with other VPCs in this aws account or others within our organisation.
    private_subnets_cidr_blocks = list(string)
    private_subnets_ids         = list(string)
    # List of VPC public subnet cidr blocks. Must not overlap with other VPCs in this aws account or others within our organisation.
    public_subnets_cidr_blocks = list(string)
    public_subnets_ids         = list(string)
  })
  default = {
    vpc_id                      = ""
    cidr_block                  = "",
    private_subnets_cidr_blocks = [],
    private_subnets_ids         = []
    public_subnets_cidr_blocks  = []
    public_subnets_ids          = []
  }
}
variable "ha_high_availability_enabled" {
  description = "High Availability setup using Auto-Scaling Group, across AZs with Application Load Balancer"
  type        = bool
  default     = false
}
variable "ha_public_load_balancer" {
  description = "High Availability Public Load Balancer config"
  type = object({
    enabled    = bool
    arn        = string
    arn_suffix = string
    port       = number
    ssl_cert = object({
      use_amazon_provider = bool
      # Has the overhead of needing external DNS verification to activate it
      use_self_signed = bool
    })
    alb_listener_arn      = string
    alb_listener_priority = number
    security_group_id     = string
    allowed_ingress_cidrs = object({
      https = list(string)
    })
    disallow_ingress_internal_health_check_from_cidrs = list(string)
    # Dont want users reaching internal healthcheck page
  })
  default = {
    enabled    = false
    arn        = ""
    arn_suffix = ""
    port       = 443
    ssl_cert = {
      use_amazon_provider = true
      # Has the overhead of needing external DNS verification to activate it
      use_self_signed = false
    }
    alb_listener_arn      = ""
    alb_listener_priority = 100
    security_group_id     = ""
    allowed_ingress_cidrs = {
      https = []
    }
    disallow_ingress_internal_health_check_from_cidrs = []
  }
}
variable "ha_private_load_balancer" {
  description = "High Availability Private Load Balancer config"
  type = object({
    enabled    = bool
    arn        = string
    arn_suffix = string
    port       = number
    ssl_cert = object({
      use_amazon_provider = bool
      # Has the overhead of needing external DNS verification to activate it
      use_self_signed = bool
    })
    alb_listener_arn      = string
    alb_listener_priority = number
    security_group_id     = string
    allowed_ingress_cidrs = object({
      https = list(string)
    })
    disallow_ingress_internal_health_check_from_cidrs = list(string)
    # Dont want users reaching internal healthcheck page
  })
  default = {
    enabled    = false
    arn        = ""
    arn_suffix = ""
    port       = 443
    ssl_cert = {
      use_amazon_provider = true
      # Has the overhead of needing external DNS verification to activate it
      use_self_signed = false
    }
    alb_listener_arn      = ""
    alb_listener_priority = 100
    security_group_id     = ""
    allowed_ingress_cidrs = {
      https = []
    }
    disallow_ingress_internal_health_check_from_cidrs = []
  }
}
variable "ha_auto_scaling_group" {
  description = "High Availability Auto Scaling Group config."
  type = object({
    health_check_grace_period      = number
    default_cooldown               = number
    suspended_processes            = list(string)
    cloudwatch_alarm_sns_topic_arn = string
    check_efs_asg_max_attempts     = number
    max_size                       = number
    min_size                       = number
    desired_capacity               = number
    # This only makes sense when below scaling_policy.enabled = false
    target_group_name_prefix = string
    # Max 20 chars !! due to limitation on length of ASG TargetGroups which need to be unique
  })
  default = {
    health_check_grace_period      = 300
    default_cooldown               = 300
    suspended_processes            = []
    cloudwatch_alarm_sns_topic_arn = ""
    check_efs_asg_max_attempts     = 60
    max_size                       = 3
    min_size                       = 1
    desired_capacity               = -1
    # This only makes sense when below scaling_policy.enabled = false
    target_group_name_prefix = ""
  }
}

variable "name_suffix" {
  description = "The AWS name suffix for AWS resources"
  type        = string
  default     = ""
}
variable "domain_name" {
  type        = string
  description = "DNS Domain name"
  default     = ""
}
variable "domain_netbios_name" {
  type        = string
  description = "NetBIOS Domain name (aka Legacy Domain Name). Limited to 15 chars and in UPPERCASE."
  default     = ""
}
variable "domain_join_user_name" {
  type        = string
  description = ""
  default     = ""
}
variable "domain_join_user_password" {
  type        = string
  description = ""
  default     = ""
}
variable "domain_login_allowed_users" {
  type        = list(string)
  description = "Active Directory User Names that allowed to RDP login to computer"
  default     = []
}
variable "domain_login_allowed_groups" {
  type        = list(string)
  description = "Active Directory Groups that allowed to RDP login to computer"
  default     = []
}
variable "domain_security_group_ids" {
  type        = list(string)
  description = "The IDs of any Domain-related security groups to be applied"
  default     = []
}
variable "aws_instance_type" {
  type = string
  # e.g. m5.micro
  default = ""
}
variable "server_listening_port" {
  description = "The port for the application to listen on upon the ec2 instance. Note: In HA the ALB will probably listen on a different port such as 443"
  type        = number
  default     = 443
}
variable "aws_ami_id" {
  type    = string
  default = ""
}
variable "aws_ssh_key_name" {
  type    = string
  default = ""
}
variable "app_ssh_public_key" {
  type    = string
  default = ""
}
variable "iam_instance_profile" {
  type    = string
  default = ""
}
variable "iam_instance_role_arn" {
  type    = string
  default = ""
}
variable "disk_root" {
  description = "Disk storage for root"
  type = object({
    encrypted = bool
  })
  default = {
    encrypted = true
  }
}
variable "disk_prpl_home" {
  description = "Disk storage options for PRPL Home Dir. Will be mounted at /mnt/prpl and symlinked to /var/lib/prpl"
  type = object({
    enabled = bool
    type    = string
    # EBS or EFS
    encrypted = bool
    size      = number
    # In Gigabytes
  })
  default = {
    enabled   = true
    type      = "EBS"
    encrypted = true
    size      = "20"
  }
}
variable "allowed_ingress_cidrs" {
  type = object({
    https = list(string)
    http  = list(string)
    ssh   = list(string)
  })
}
variable "allowed_egress_cidrs" {
  type = object({
    http              = list(string)
    https             = list(string)
    telegraf_influxdb = list(string)
  })
}
variable "cloudwatch_alarm_default_sns_topic_arn" {
  type    = string
  default = ""
}
variable "cloudwatch_enabled" {
  type    = bool
  default = true
}
variable "cloudwatch_refresh_interval_secs" {
  type    = number
  default = 60
}
variable "telegraf_enabled" {
  type    = bool
  default = true
}
variable "telegraf_influxdb_url" {
  type    = string
  default = ""
}
variable "telegraf_influxdb_password_secret_id" {
  type      = string
  default   = ""
  sensitive = true
}
variable "telegraf_influxdb_retention_policy" {
  type    = string
  default = "autogen"
}
variable "telegraf_influxdb_https_insecure_skip_verify" {
  type    = bool
  default = false
}
variable "global_default_tags" {
  description = "Global default tags"
  default     = {}
  type        = map(string)
}
variable "prpl_linux_user_name" {
  description = "Linux user for running PRPL process under."
  type        = string
  default     = "prpl"
}
variable "prpl_linux_user_group" {
  description = "Linux user group for running PRPL process under."
  type        = string
  default     = "prpl"
}
variable "prpl_user_ssh_public_key" {
  description = "SSH Public Key for ssh login as PRPL user"
  type        = string
  default     = ""
}
//variable "prpl_worker_ssh_public_key" {
//  description = "SSH Public Key for ssh login as PRPL Worker user on PRPL Node"
//  type        = string
//  default     = ""
//}
//variable "prpl_config_file_pathnames" {
//  description = "Config file path and names to be loaded by PRPL configuration-as-code plugin on 1st launch."
//  type        = list(string)
//  default     = []
//}
//variable "prpl_config_files" {
//  description = "Config file names and base64-encoded contents to be loaded by PRPL configuration-as-code plugin on 1st launch."
//  type = list(object({
//    filename          = string
//    contents_base64   = string
//    contents_md5_hash = string
//  }))
//  default = []
//}
variable "prpl_db_admin_user_password_secret_id" {
  description = "AWS Secrets ID for password to login to Database server as 'admin' user."
  type        = string
  default     = ""
}
variable "prpl_admin_user_password_secret_id" {
  description = "AWS Secrets ID for password to login to PRPL application as 'admin' user."
  type        = string
  default     = ""
}
