output "primary_vpc_id" {
  description = "Primary VPC ID"
  value       = local.primary_vpc_id
}

output "dr_vpc_id" {
  description = "DR VPC ID"
  value       = local.dr_vpc_id
}

output "primary_alb_dns_name" {
  description = "DNS name of the primary ALB"
  value       = module.primary_alb.alb_dns_name
}

output "dr_alb_dns_name" {
  description = "DNS name of the DR ALB"
  value       = module.dr_alb.alb_dns_name
}

output "primary_efs_id" {
  description = "Primary EFS file system ID"
  value       = module.primary_efs.file_system_id
}

output "dr_efs_id" {
  description = "DR EFS file system ID"
  value       = module.dr_efs.file_system_id
}

output "primary_asg_name" {
  description = "Primary ASG name"
  value       = module.primary_asg.asg_name
}

output "dr_asg_name" {
  description = "DR ASG name"
  value       = module.dr_asg.asg_name
}

output "deploy_private_key_pem" {
  description = "Private key for the dedicated EC2 deploy key pair; store it as VM_SSH_PRIVATE_KEY"
  value       = tls_private_key.deploy.private_key_pem
  sensitive   = true
}

output "alerts_topic_arn" {
  description = "SNS topic ARN for primary and DR monitoring alerts"
  value       = aws_sns_topic.alerts.arn
}