# outputs.tf
# ==========
# Outputs are values Terraform prints after "terraform apply" finishes.
# The most important one is alb_url — that's the URL you open in your browser.

# Open this URL in your browser. Your app is running here.
output "alb_url" {
  description = "Open this URL in your browser. Your app is running here."
  value       = "http://${aws_lb.main.dns_name}"
}

# The private address of your database. Used internally by the app.
output "rds_endpoint" {
  description = "The private address of your database. Used internally by the app."
  value       = aws_db_instance.postgres.address
}

# The name of your Auto Scaling Group — use this to find instances in the AWS Console.
output "asg_name" {
  description = "The name of your Auto Scaling Group — use this to find instances in the AWS Console."
  value       = aws_autoscaling_group.app.name
}

# Your VPC ID — useful for reference in the AWS Console.
output "vpc_id" {
  description = "Your VPC ID — useful for reference in the AWS Console."
  value       = aws_vpc.main.id
}
