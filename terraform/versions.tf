terraform {
  required_version = ">= 1.6.0"

  cloud {
    organization = "YOUR_TERRAFORM_CLOUD_ORG"
    workspaces {
      name = "k8s-dr-project"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
