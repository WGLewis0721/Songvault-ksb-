# ---------------------------------------------------------------------------
# terraform/asg.tf
# Auto Scaling Group — keeps a fleet of EC2 instances running and healthy.
# If an instance becomes unhealthy (fails ALB health checks), the ASG
# terminates it and launches a replacement automatically.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Auto Scaling Group — maintains between min_size and max_size instances.
# Instances are spread across both private subnets (two AZs) so the app
# survives an entire Availability Zone outage.
# ---------------------------------------------------------------------------
resource "aws_autoscaling_group" "main" {
  name = "${var.project_name}-asg"

  # Keep at least 2 instances (one per AZ) so the app is always available.
  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  # Place instances in the private subnets — they are not directly internet-
  # facing; the ALB routes traffic to them.
  vpc_zone_identifier = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  # Reference the Launch Template defined in launch_template.tf.
  # "$Latest" means the ASG always uses the most recently updated version.
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Register instances with the ALB target group so the ALB can send traffic
  # to them and monitor their health.
  target_group_arns = [aws_lb_target_group.main.arn]

  # Use the ALB health check (HTTP GET /) rather than the basic EC2 status
  # check so instances that are running but serving errors get replaced.
  health_check_type         = "ELB"
  health_check_grace_period = 300 # seconds — gives new instances time to boot

  # Propagate the Name tag to every EC2 instance the ASG launches.
  tag {
    key                 = "Name"
    value               = "${var.project_name}-app"
    propagate_at_launch = true
  }
}
