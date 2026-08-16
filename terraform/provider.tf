terraform {
  required_version = ">= 1.15.8"

  cloud {
    
    organization = "Eohoi_Miracle"

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

provider "aws" {
  region = "eu-north-1"
}
