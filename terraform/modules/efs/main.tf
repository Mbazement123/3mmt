terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

resource "aws_efs_file_system" "this" {
  creation_token = "${var.name}-efs"
  encrypted      = true

  tags = {
    Name = "${var.name}-efs"
  }
}

resource "aws_efs_mount_target" "this" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [var.security_group_id]
}

output "file_system_id" {
  value = aws_efs_file_system.this.id
}

output "file_system_arn" {
  value = aws_efs_file_system.this.arn
}

output "mount_target_ids" {
  value = aws_efs_mount_target.this[*].id
}
