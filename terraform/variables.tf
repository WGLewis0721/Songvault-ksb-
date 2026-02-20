# ---------------------------------------------------------------------------
# terraform/variables.tf
# Input variables for the SongVault stack.  Override any of these in
# terraform.tfvars or with -var flags on the command line.
# ---------------------------------------------------------------------------

# AWS region where every resource will be created.
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

# Short prefix used in every resource name so it is easy to identify SongVault
# resources in the AWS console.
variable "project_name" {
  description = "Short name prefix applied to every resource"
  type        = string
  default     = "songvault"
}

# PostgreSQL master username.  Must match the value app.py receives via the
# DB_USER environment variable at runtime.
variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "songvault_user"
}

# PostgreSQL master password.  Marked sensitive so Terraform never prints it
# in plan/apply output.  Set this in terraform.tfvars — never hard-code it here.
variable "db_password" {
  description = "PostgreSQL master password (sensitive)"
  type        = string
  sensitive   = true
}
