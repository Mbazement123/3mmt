variable "target_vpc_id" {
  type        = string
  description = "The ID of your existing AWS VPC"
}

variable "target_subnet_id" {
  type        = string
  description = "The ID of your existing shared AWS Subnet"
}

variable "ssh_public_key" {
  type        = string
  description = "The SSH public key used to access the EC2 instance"
}
