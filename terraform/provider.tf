provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}
