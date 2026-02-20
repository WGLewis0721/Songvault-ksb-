# rds.tf
# ======
# RDS = Relational Database Service. Amazon runs the database for us.
# We don't have to install PostgreSQL, manage backups, or handle server patches.
# We just tell AWS what size database we want and it handles the rest.
# Our database lives in private subnets — it is never reachable from the internet.

# ---------------------------------------------------------------------------
# Tells RDS which subnets it can use. We give it both private subnets so AWS
# knows the database should never be in a public subnet. Two subnets in
# different AZs are required even if multi_az is false.
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name      = "${var.project_name}-db-subnet-group"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# RDS PostgreSQL instance — the single source of truth for all song and
# setlist data. It lives in the private subnets and is only accessible from
# EC2 instances that belong to app_sg.
# ---------------------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  # Identifier shown in the RDS console — must be unique per region per account.
  identifier = "${var.project_name}-db"

  # PostgreSQL version 15 — stable and widely supported.
  engine         = "postgres"
  engine_version = "15"

  # The smallest RDS instance. Costs ~$0.017/hour. Fine for a portfolio project.
  # In production you would use db.t3.small or larger.
  instance_class = "db.t3.micro"

  # 20 GiB of SSD storage — the minimum RDS allows.
  allocated_storage = 20
  storage_type      = "gp2"

  # Always encrypt database storage. This is a security best practice and
  # costs nothing extra. Protects data if someone gets the physical disk.
  storage_encrypted = true

  # The database name created automatically when the instance first boots.
  db_name  = "songvault"
  username = var.db_username
  password = var.db_password

  # Place the instance in the private subnets defined in networking.tf.
  db_subnet_group_name = aws_db_subnet_group.main.name

  # Only app_sg can reach this instance — never open to the internet.
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Multi-AZ means AWS keeps a hot standby in a second data center.
  # Set to true in production for automatic failover. We set false to save cost.
  multi_az = false

  # The database CANNOT be reached from the internet.
  # Only resources inside our VPC with the right security group can connect.
  publicly_accessible = false

  # When we run terraform destroy, skip making a backup.
  # Fine for a portfolio project. In production, ALWAYS set this to false
  # and name the snapshot so you can restore your data.
  skip_final_snapshot = true

  deletion_protection = false

  tags = {
    Name      = "${var.project_name}-postgres"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}
