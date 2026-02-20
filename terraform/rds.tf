# ---------------------------------------------------------------------------
# terraform/rds.tf
# Provisions a managed PostgreSQL database using Amazon RDS.
# RDS handles backups, patching, and failover so we don't have to manage a
# database server ourselves.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# DB Subnet Group — tells RDS which subnets it may place database instances
# into.  We use both private subnets so RDS can fail over between AZs if
# multi_az is ever enabled.
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# ---------------------------------------------------------------------------
# RDS PostgreSQL instance — the single source of truth for all song and
# setlist data.  It lives in the private subnets and is only accessible from
# EC2 instances that belong to app_sg.
# ---------------------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  # Identifier shown in the RDS console — must be unique per region per account.
  identifier = "${var.project_name}-db"

  # PostgreSQL engine version 15.4.
  engine         = "postgres"
  engine_version = "15.4"

  # db.t3.micro is Free-Tier eligible and perfectly sized for a portfolio app.
  instance_class = "db.t3.micro"

  # 20 GiB of SSD storage — the minimum RDS allows.
  allocated_storage = 20

  # The database name created automatically when the instance first boots.
  db_name  = "songvault"
  username = var.db_username
  password = var.db_password

  # Place the instance in the private subnets defined above.
  db_subnet_group_name = aws_db_subnet_group.main.name

  # Only app_sg can reach this instance — never open to the internet.
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Skip taking a final snapshot when `terraform destroy` is run.
  # In a real production database you would set this to false and configure
  # a proper retention policy before destroying.
  skip_final_snapshot = true

  # Single-AZ for cost efficiency in a portfolio project.
  # Set multi_az = true in production for automatic failover.
  multi_az = false

  # Do NOT make the database reachable from the internet.
  publicly_accessible = false

  tags = {
    Name = "${var.project_name}-postgres"
  }
}
