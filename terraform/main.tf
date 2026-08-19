locals {
  primary_vpc_id        = var.create_primary_vpc ? module.primary_network[0].vpc_id : var.primary_vpc_id
  primary_subnets       = var.create_primary_vpc ? module.primary_network[0].public_subnet_ids : var.primary_subnet_ids
  dr_vpc_id             = var.create_dr_vpc ? module.dr_network[0].vpc_id : var.dr_vpc_id
  dr_subnets            = var.create_dr_vpc ? module.dr_network[0].public_subnet_ids : var.dr_subnet_ids
  primary_ami_copy_name = "${var.project_name}-dr-ami"
}

module "primary_network" {
  count  = var.create_primary_vpc ? 1 : 0
  source = "./modules/networking"

  name       = "${var.project_name}-primary"
  cidr_block = var.vpc_cidr_primary
  azs        = var.primary_azs
}

module "dr_network" {
  count  = var.create_dr_vpc ? 1 : 0
  source = "./modules/networking"

  providers = {
    aws = aws.dr
  }

  name       = "${var.project_name}-dr"
  cidr_block = var.vpc_cidr_dr
  azs        = var.dr_azs
}

module "primary_security" {
  source = "./modules/security"

  name   = "${var.project_name}-primary"
  vpc_id = local.primary_vpc_id
}

module "dr_security" {
  source = "./modules/security"

  providers = {
    aws = aws.dr
  }

  name   = "${var.project_name}-dr"
  vpc_id = local.dr_vpc_id
}

module "primary_efs" {
  source = "./modules/efs"

  name              = "${var.project_name}-primary"
  subnet_ids        = local.primary_subnets
  security_group_id = module.primary_security.efs_security_group_id
}

module "dr_efs" {
  source = "./modules/efs"

  providers = {
    aws = aws.dr
  }

  name              = "${var.project_name}-dr"
  subnet_ids        = local.dr_subnets
  security_group_id = module.dr_security.efs_security_group_id
}

module "primary_alb" {
  source = "./modules/alb"

  name              = "${var.project_name}-primary"
  vpc_id            = local.primary_vpc_id
  subnet_ids        = local.primary_subnets
  security_group_id = module.primary_security.alb_security_group_id
  target_port       = var.target_port
}

module "dr_alb" {
  source = "./modules/alb"

  providers = {
    aws = aws.dr
  }

  name              = "${var.project_name}-dr"
  vpc_id            = local.dr_vpc_id
  subnet_ids        = local.dr_subnets
  security_group_id = module.dr_security.alb_security_group_id
  target_port       = var.target_port
}

resource "aws_ami_copy" "dr_ami" {
  provider = aws.dr

  name              = local.primary_ami_copy_name
  source_ami_id     = var.app_ami_id
  source_ami_region = var.primary_region
  encrypted         = true
}

module "primary_asg" {
  source = "./modules/asg"

  name               = "${var.project_name}-primary-asg"
  vpc_subnet_ids     = local.primary_subnets
  security_group_ids = [module.primary_security.app_security_group_id]
  target_group_arn   = module.primary_alb.target_group_arn
  efs_file_system_id = module.primary_efs.file_system_id
  region             = var.primary_region
  ami_id             = var.app_ami_id
  instance_type      = var.instance_type
  key_name           = var.key_name
  min_size           = 1
  max_size           = 2
  desired_capacity   = 1
}

module "dr_asg" {
  source = "./modules/asg"

  providers = {
    aws = aws.dr
  }

  name               = "${var.project_name}-dr-asg"
  vpc_subnet_ids     = local.dr_subnets
  security_group_ids = [module.dr_security.app_security_group_id]
  target_group_arn   = module.dr_alb.target_group_arn
  efs_file_system_id = module.dr_efs.file_system_id
  region             = var.dr_region
  ami_id             = aws_ami_copy.dr_ami.id
  instance_type      = var.instance_type
  key_name           = var.key_name
  min_size           = 1
  max_size           = 1
  desired_capacity   = 1
}
