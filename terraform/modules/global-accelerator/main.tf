terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_globalaccelerator_accelerator" "this" {
  name            = var.name
  ip_address_type = "IPV4"
  enabled         = true
}

resource "aws_globalaccelerator_listener" "this" {
  for_each = {
    http  = 80
    https = 443
  }

  accelerator_arn = aws_globalaccelerator_accelerator.this.id
  protocol        = "TCP"

  port_range {
    from_port = each.value
    to_port   = each.value
  }
}

resource "aws_globalaccelerator_endpoint_group" "primary" {
  for_each = aws_globalaccelerator_listener.this

  listener_arn                  = each.value.id
  endpoint_group_region         = var.primary_region
  health_check_protocol         = var.health_check_protocol
  health_check_port             = var.health_check_port
  health_check_path             = "/"
  health_check_interval_seconds = var.health_check_interval_seconds
  threshold_count               = var.health_check_threshold_count

  endpoint_configuration {
    endpoint_id = var.primary_alb_arn
    weight      = 100
  }
}

resource "aws_globalaccelerator_endpoint_group" "secondary" {
  for_each = aws_globalaccelerator_listener.this

  listener_arn                  = each.value.id
  endpoint_group_region         = var.secondary_region
  health_check_protocol         = var.health_check_protocol
  health_check_port             = var.health_check_port
  health_check_path             = "/"
  health_check_interval_seconds = var.health_check_interval_seconds
  threshold_count               = var.health_check_threshold_count

  endpoint_configuration {
    endpoint_id = var.secondary_alb_arn
    weight      = 100
  }
}