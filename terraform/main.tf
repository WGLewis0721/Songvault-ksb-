# ---------------------------------------------------------------------------
# terraform/main.tf
# This is the entry point for Terraform. It tells Terraform which version
# to use and which cloud provider to connect to.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# This tells Terraform to build everything in the AWS region you specify in
# variables.tf. Default is us-east-1 (Northern Virginia).
provider "aws" {
  region = var.aws_region
}
