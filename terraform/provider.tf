terraform {
  required_version = "~> 1.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn    = var.deployment_role_arn
  }

  default_tags {
    tags = {
      Deployment = "terraform"
    }
  }
}

provider "aws" {
  alias  = "NVirginia"
  region = "us-east-1"
  assume_role {
    role_arn    = var.deployment_role_arn
  }

  default_tags {
    tags = {
      Deployment = "terraform"
    }
  }
}