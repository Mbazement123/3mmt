variable "name" {
  description = "Name of the Global Accelerator"
  type        = string
}

variable "primary_alb_arn" {
  description = "ARN of the primary-region ALB"
  type        = string
}

variable "secondary_alb_arn" {
  description = "ARN of the secondary-region ALB"
  type        = string
}

variable "primary_region" {
  description = "AWS region containing the primary ALB"
  type        = string
}

variable "secondary_region" {
  description = "AWS region containing the secondary ALB"
  type        = string
}

variable "health_check_protocol" {
  description = "Protocol used by Global Accelerator endpoint health checks"
  type        = string
  default     = "HTTP"

  validation {
    condition     = contains(["HTTP", "HTTPS"], var.health_check_protocol)
    error_message = "health_check_protocol must be HTTP or HTTPS."
  }
}

variable "health_check_port" {
  description = "Port used by Global Accelerator endpoint health checks"
  type        = number
  default     = 80

  validation {
    condition     = var.health_check_port >= 1 && var.health_check_port <= 65535
    error_message = "health_check_port must be between 1 and 65535."
  }
}

variable "health_check_interval_seconds" {
  description = "Interval between Global Accelerator endpoint health checks"
  type        = number
  default     = 10

  validation {
    condition     = contains([10, 30], var.health_check_interval_seconds)
    error_message = "health_check_interval_seconds must be 10 or 30."
  }
}

variable "health_check_threshold_count" {
  description = "Consecutive health checks required for an endpoint to be considered healthy"
  type        = number
  default     = 3

  validation {
    condition     = var.health_check_threshold_count >= 1 && var.health_check_threshold_count <= 10
    error_message = "health_check_threshold_count must be between 1 and 10."
  }
}