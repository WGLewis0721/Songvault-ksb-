# ---------------------------------------------------------------------------
# terraform/security_groups.tf
# Three security groups following the principle of least privilege:
#   alb_sg  — only the load balancer; accepts HTTP from the internet
#   app_sg  — only the Flask app servers; accepts traffic from alb_sg only
#   rds_sg  — only the database; accepts traffic from app_sg only
# This "chain" means RDS is never reachable from the internet.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ALB Security Group — the load balancer needs to accept HTTP on port 80 from
# anywhere on the internet (that's its job) and send traffic outward to EC2.
# ---------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP inbound to the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Allow inbound HTTP from the entire internet so users can reach the site.
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound so the ALB can forward requests to EC2 instances.
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ---------------------------------------------------------------------------
# App Security Group — EC2 Flask servers accept traffic on port 8080 ONLY from
# the ALB security group.  This means direct internet access to the app
# servers is impossible — all traffic must go through the load balancer.
# ---------------------------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Allow port 8080 from ALB only"
  vpc_id      = aws_vpc.main.id

  # Accept Flask app traffic only from the ALB (security_groups reference).
  ingress {
    description             = "Flask app port from ALB"
    from_port               = 8080
    to_port                 = 8080
    protocol                = "tcp"
    security_groups         = [aws_security_group.alb_sg.id]
  }

  # Allow all outbound so EC2 can reach RDS and download packages via NAT.
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# ---------------------------------------------------------------------------
# RDS Security Group — the database accepts PostgreSQL (port 5432) ONLY from
# the app security group.  No public egress is needed because RDS initiates no
# outbound connections.
# ---------------------------------------------------------------------------
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL from app servers only"
  vpc_id      = aws_vpc.main.id

  # Accept database connections only from EC2 instances in app_sg.
  ingress {
    description             = "PostgreSQL from app servers"
    from_port               = 5432
    to_port                 = 5432
    protocol                = "tcp"
    security_groups         = [aws_security_group.app_sg.id]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}
