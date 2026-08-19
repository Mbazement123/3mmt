variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "dr_region" {
  description = "Disaster recovery AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name prefix used across AWS resources"
  type        = string
  default     = "biodata"
}

variable "vpc_cidr_primary" {
  description = "CIDR block for the primary-region VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "vpc_cidr_dr" {
  description = "CIDR block for the DR-region VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "primary_azs" {
  description = "Availability zones to use in the primary region"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "dr_azs" {
  description = "Availability zones to use in the DR region"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "app_ami_id" {
  description = "Custom AMI ID in the primary region for the ASG launch template"
  type        = string
  default     = "ami-05697bc11ddda1f1a"
}

variable "instance_type" {
  description = "EC2 instance type used in the ASG launch template"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Existing EC2 SSH key pair name"
  type        = string
  default     = "biodata-project-key"
}

variable "target_port" {
  description = "Application port exposed by the service behind the ALB"
  type        = number
  default     = 3000
}

variable "create_primary_vpc" {
  description = "Set to true to create the primary VPC and subnets"
  type        = bool
  default     = true
}

variable "create_dr_vpc" {
  description = "Set to true to create the DR VPC and subnets"
  type        = bool
  default     = true
}

variable "primary_vpc_id" {
  description = "Optional existing VPC ID for the primary region"
  type        = string
  default     = null
}

variable "primary_subnet_ids" {
  description = "Optional existing public subnet IDs for the primary region"
  type        = list(string)
  default     = []
}

variable "dr_vpc_id" {
  description = "Optional existing VPC ID for the DR region"
  type        = string
  default     = null
}

variable "dr_subnet_ids" {
  description = "Optional existing public subnet IDs for the DR region"
  type        = list(string)
  default     = []
}
