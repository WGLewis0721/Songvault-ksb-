# ---------------------------------------------------------------------------
# terraform/variables.tf
# Input variables for the SongVault stack.  Set values in terraform.tfvars
# (copy from terraform.tfvars.example — never commit real secrets).
# ---------------------------------------------------------------------------

# The AWS region where everything gets built. us-east-1 is a good default —
# it has the most services available and tends to be cheapest.
variable "aws_region" {
  description = "The AWS region where everything gets built"
  type        = string
  default     = "us-east-1"
}

# Used as a prefix on every resource name so you can find your stuff in the
# AWS console. Example: songvault-vpc, songvault-alb, songvault-db
variable "project_name" {
  description = "Short name prefix applied to every resource"
  type        = string
  default     = "songvault"
}

# The username the app uses to log into the database.
variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "songvault_user"
}

# The database password. You set this in terraform.tfvars (never in this file).
# sensitive=true means Terraform won't show it in logs or terminal output.
variable "db_password" {
  description = "PostgreSQL master password — set this in terraform.tfvars, never here"
  type        = string
  sensitive   = true
}
