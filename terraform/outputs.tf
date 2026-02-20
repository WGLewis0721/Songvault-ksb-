# ---------------------------------------------------------------------------
# terraform/outputs.tf
# Values printed after `terraform apply` so you can immediately use the stack.
# ---------------------------------------------------------------------------

# The full HTTP URL of the Application Load Balancer.  Open this in your
# browser to reach the SongVault app.
output "alb_dns_name" {
  description = "Open this URL in your browser"
  value       = "http://${aws_lb.main.dns_name}"
}

# The private DNS endpoint of the RDS PostgreSQL instance.  EC2 instances
# inside the VPC use this to connect; it is never reachable from the internet.
output "rds_endpoint" {
  description = "RDS private endpoint"
  value       = aws_db_instance.postgres.address
}

# The name of the Auto Scaling Group.  Useful for AWS CLI commands such as
# `aws autoscaling describe-auto-scaling-groups`.
output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.main.name
}
