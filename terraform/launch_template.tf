# ---------------------------------------------------------------------------
# terraform/launch_template.tf
# Defines the blueprint for every EC2 instance in the Auto Scaling Group.
# The Launch Template captures: which AMI, what instance type, which security
# group, and the user-data script that bootstraps the Flask app on first boot.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Look up the latest Ubuntu 22.04 LTS (Jammy) AMI from Canonical's official
# AWS account (099720109477).  Using a data source means you always get the
# most up-to-date patched image without editing Terraform.
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# Launch Template — the blueprint for EC2 instances in the ASG.
# The user_data is a bash script (user-data.sh) rendered with templatefile so
# database credentials are injected at deployment time — not hard-coded.
# ---------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # Attach only the app security group so this instance is reachable only from
  # the ALB — not directly from the internet.
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # The user_data script is base64-encoded as required by AWS.
  # templatefile injects DB connection details so the Flask app can connect.
  user_data = base64encode(templatefile("${path.module}/../scripts/user-data.sh", {
    db_host = aws_db_instance.postgres.address
    db_name = "songvault"
    db_user = var.db_username
    db_pass = var.db_password
  }))

  # Tag every EC2 instance launched from this template with a friendly name.
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-app"
    }
  }
}
