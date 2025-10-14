terraform {
  cloud {
    organization = "jb-smoker"
    workspaces {
      name = "jetstream"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.16.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
