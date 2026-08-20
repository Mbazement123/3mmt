variable "name" {
  description = "Name prefix for the AWS Backup resources"
  type        = string
}

variable "efs_file_system_arn" {
  description = "ARN of the EFS file system to back up"
  type        = string
}

variable "backup_role_arn" {
  description = "ARN of the AWS Backup service role"
  type        = string
}

variable "backup_schedule" {
  description = "AWS Backup cron expression in UTC"
  type        = string
  default     = "cron(0 5 * * ? *)"
}

variable "retention_days" {
  description = "Number of days to retain EFS recovery points"
  type        = number
  default     = 35

  validation {
    condition     = var.retention_days >= 1
    error_message = "retention_days must be at least 1."
  }
}