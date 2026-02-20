# security.tf
# ===========
# Security Groups are like firewall rules for AWS resources.
# Each rule says: "allow THIS type of traffic from THIS source."
# We follow the principle of least-privilege: only open what is
# absolutely necessary, nothing more.
#
# Our three security groups form a chain:
#   Internet → [alb_sg] → [app_sg] → [rds_sg]
# Each layer only accepts traffic from the layer before it.

# ---------------------------------------------------------------------------
# ALB Security Group — the load balancer accepts HTTP from the public internet
# and can only send traffic onward to app servers on port 8080.
# ---------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Firewall rules for the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP from anywhere on the internet — this is the public entry point.
  # Port 80 is standard HTTP. The ALB is the ONLY thing that faces the public internet.
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # The ALB can ONLY send traffic to app servers on port 8080.
  # It cannot reach the database or any other resource directly.
  egress {
    description     = "Forward to app servers on port 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  tags = {
    Name      = "${var.project_name}-alb-sg"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# App Security Group — EC2 Flask servers only accept connections from the ALB.
# They are in private subnets with no public IPs, so the internet cannot reach
# them directly. Even if someone found the private IP, this rule blocks it.
# ---------------------------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Firewall rules for EC2 app servers"
  vpc_id      = aws_vpc.main.id

  # App servers ONLY accept connections from the load balancer.
  ingress {
    description     = "Flask app port from ALB only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # App servers need to make outbound connections to: reach RDS on port 5432,
  # call AWS APIs, and go through NAT Gateway to install packages on boot.
  egress {
    description = "Allow all outbound for package installs, RDS, and AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.project_name}-app-sg"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# RDS Security Group — the database ONLY accepts connections from app servers.
# Port 5432 is the standard PostgreSQL port.
# The database cannot be reached from the internet under any circumstances.
# ---------------------------------------------------------------------------
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Firewall rules for the PostgreSQL database"
  vpc_id      = aws_vpc.main.id

  # The database ONLY accepts connections from app servers.
  ingress {
    description     = "PostgreSQL from app servers only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  # Database only needs to respond back within the VPC network.
  egress {
    description = "Respond within VPC only"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name      = "${var.project_name}-rds-sg"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}
