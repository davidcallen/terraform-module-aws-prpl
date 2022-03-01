output "target_group_public_http" {
  value = aws_lb_target_group.prpl-public-https
}
output "aws_instance_private_ip" {
  value = (var.ha_high_availability_enabled == false) ? aws_instance.prpl[0].private_ip : ""
}
output "aws_instance_public_ip" {
  value = (var.ha_high_availability_enabled == false) ? aws_instance.prpl[0].public_ip : ""
}
