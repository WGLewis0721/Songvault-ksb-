# compute.tf
# ==========
# This file defines our EC2 app servers and how they scale automatically.
#
# Key concepts:
#   IAM Role        = Permission card that EC2 instances carry
#   Launch Template = The blueprint for every EC2 instance (OS, size, startup script)
#   Auto Scaling Group (ASG) = The manager that keeps the right number of instances running
#
# When the ASG sees an instance is unhealthy, it terminates it and launches a new one
# from the Launch Template automatically. This is "self-healing" infrastructure.

# ---------------------------------------------------------------------------
# IAM Role — An IAM Role is like a permission card. We attach it to EC2
# instances so they can call AWS APIs. We grant ONLY what the app needs —
# nothing more. DO NOT grant AdministratorAccess to EC2 instances.
# That would be a serious security risk.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-ec2-role"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Allows EC2 instances to send logs to CloudWatch so we can read them in the
# AWS console without SSH-ing into the server.
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ---------------------------------------------------------------------------
# Allows AWS Systems Manager Session Manager. This gives you a browser-based
# terminal into your EC2 instances without opening port 22 or managing SSH keys.
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ---------------------------------------------------------------------------
# An instance profile is the wrapper that lets you attach an IAM role to an EC2
# instance. Think of it as the card holder for the permission card.
# ---------------------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name      = "${var.project_name}-ec2-profile"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Finds the latest Ubuntu 22.04 LTS AMI automatically. 099720109477 is
# Canonical's official AWS account ID (the company that makes Ubuntu).
# Using a data source means we never have to update a hardcoded AMI ID.
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
# The Launch Template is the blueprint for every EC2 instance in our fleet.
# When the ASG needs a new instance, it stamps one out from this template.
# user_data is a startup script that runs once when the instance first boots.
# templatefile() injects the database password into the script at deploy time.
# ---------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # Attach only the app security group — reachable only from the ALB.
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # Attach the IAM instance profile so the EC2 instance can use SSM and CloudWatch.
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  # The user_data script is base64-encoded as required by AWS.
  # templatefile() replaces ${db_host}, ${db_name}, ${db_user}, ${db_pass} at
  # deploy time so real credentials are never stored in source code.
  user_data = base64encode(templatefile("${path.module}/../scripts/user-data.sh", {
    db_host = aws_db_instance.postgres.address
    db_name = "songvault"
    db_user = var.db_username
    db_pass = var.db_password
  }))

  # Tag every EC2 instance launched from this template.
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name      = "${var.project_name}-app-server"
      Project   = var.project_name
      Owner     = "student"
      ManagedBy = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# Auto Scaling Group — maintains between min_size and max_size instances.
# Instances are spread across both private subnets (two AZs) so the app
# survives an entire Availability Zone outage.
# ---------------------------------------------------------------------------
resource "aws_autoscaling_group" "app" {
  name = "${var.project_name}-asg"

  # Always keep at least 2 instances running — one in each AZ.
  # This is the minimum for real high availability.
  min_size = 2

  # The ASG will never launch more than 4 instances. This is a cost safety net.
  max_size = 4

  # Start with 2 instances. The ASG will try to maintain this count.
  desired_capacity = 2

  # Spread instances across both private subnets (both AZs).
  # If one data center has an outage, instances in the other AZ keep running.
  vpc_zone_identifier = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  # Register instances with the ALB target group so traffic reaches them.
  target_group_arns = [aws_lb_target_group.app.arn]

  # Use the ALB's health check results to decide if an instance is healthy.
  # If the ALB says an instance is failing, the ASG will replace it.
  health_check_type = "ELB"

  # Wait 5 minutes after launch before checking health. This gives the
  # user-data bootstrap script time to finish installing the app.
  health_check_grace_period = 300

  # Reference the Launch Template — "$Latest" always uses the newest version.
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # When the launch template changes, replace instances one at a time
  # so the app stays available during updates.
  instance_refresh {
    strategy = "Rolling"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-server"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Owner"
    value               = "student"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }
}
