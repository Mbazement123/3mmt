terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_backup_vault" "this" {
  name = "${var.name}-vault"

  tags = {
    Name = "${var.name}-vault"
  }
}

resource "aws_backup_plan" "this" {
  name = "${var.name}-plan"

  rule {
    rule_name                = "daily-efs"
    target_vault_name        = aws_backup_vault.this.name
    schedule                 = var.backup_schedule
    start_window             = 60
    completion_window        = 180
    enable_continuous_backup = false

    lifecycle {
      delete_after = var.retention_days
    }
  }
}

resource "aws_backup_selection" "this" {
  iam_role_arn = var.backup_role_arn
  name         = "${var.name}-efs-selection"
  plan_id      = aws_backup_plan.this.id

  resources = [var.efs_file_system_arn]
}