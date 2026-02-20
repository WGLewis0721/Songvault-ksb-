# alb.tf
# ======
# ALB = Application Load Balancer.
# It sits in front of all our EC2 instances and distributes traffic between them.
# When you open the app URL in your browser, you're hitting the ALB.
# The ALB picks a healthy EC2 instance and forwards your request to it.
#
# Components:
#   aws_lb            = The load balancer itself
#   aws_lb_target_group = The list of EC2 instances to send traffic to
#   aws_lb_listener   = The rule: "when traffic arrives on port 80, forward to the target group"

# ---------------------------------------------------------------------------
# The ALB is internet-facing (internal=false) so users can reach it from their
# browser. It lives in public subnets in both AZs. AWS automatically routes
# around AZ failures.
# ---------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name      = "${var.project_name}-alb"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# The target group is the list of EC2 instances the ALB sends traffic to.
# Health check: every 30 seconds, the ALB does GET / on port 8080.
# If an instance responds with HTTP 200, it's healthy.
# If it fails 3 times in a row, the ALB stops sending it traffic.
# The ASG sees the instance is unhealthy and replaces it automatically.
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "8080"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name      = "${var.project_name}-tg"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# The listener is the rule that says: when traffic arrives on port 80,
# forward it to the target group. This is the glue between the ALB and
# our EC2 instances.
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
