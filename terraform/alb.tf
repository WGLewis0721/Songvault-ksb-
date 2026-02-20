# ---------------------------------------------------------------------------
# terraform/alb.tf
# Application Load Balancer (ALB) — the public-facing entry point for all
# user traffic.  It distributes requests across the EC2 instances and performs
# health checks so only healthy instances receive traffic.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ALB — an internet-facing load balancer deployed across both public subnets.
# "application" type supports HTTP/HTTPS and path-based routing rules.
# ---------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false            # internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# ---------------------------------------------------------------------------
# Target Group — the pool of EC2 instances the ALB will send traffic to.
# Health checks on port 8080 at path "/" determine which instances are healthy.
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "8080"
    healthy_threshold   = 2  # 2 consecutive successes = healthy
    unhealthy_threshold = 3  # 3 consecutive failures  = unhealthy
    interval            = 30 # check every 30 seconds
  }
}

# ---------------------------------------------------------------------------
# Listener — listens on port 80 (HTTP) and forwards every request to the
# target group defined above.  In production you would add a port-443 listener
# with an ACM certificate for HTTPS.
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
