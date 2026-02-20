# ---------------------------------------------------------------------------
# terraform/main.tf
# Root configuration: declares the Terraform version constraint and the AWS
# provider so every other file in this directory can use AWS resources.
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

# Configure the AWS provider to deploy resources into the region specified by
# the aws_region variable (default: us-east-1).
provider "aws" {
  region = var.aws_region
}
