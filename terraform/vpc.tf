# ---------------------------------------------------------------------------
# terraform/vpc.tf
# Defines the entire network layer for SongVault:
#   - One VPC with DNS enabled
#   - Two public subnets (for the ALB, one per AZ)
#   - Two private subnets (for EC2 app servers and RDS, one per AZ)
#   - Internet Gateway (lets the ALB reach the internet)
#   - NAT Gateway (lets private EC2 instances reach the internet for package
#     installs without exposing them to inbound traffic)
#   - Route tables wiring everything together
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Look up all available Availability Zones in the chosen region so we can
# spread resources across two AZs for high availability.
# ---------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------
# The VPC (Virtual Private Cloud) is your isolated section of AWS.  Think of
# it as your own private data centre inside AWS.  DNS hostnames and support
# are enabled so EC2 instances get friendly DNS names.
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ---------------------------------------------------------------------------
# Public subnet in AZ-1 — hosts the ALB front-end.  map_public_ip_on_launch
# means anything launched here gets a public IP automatically.
# ---------------------------------------------------------------------------
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-1"
  }
}

# ---------------------------------------------------------------------------
# Public subnet in AZ-2 — second ALB node for high availability.
# The ALB requires at least two subnets in different AZs.
# ---------------------------------------------------------------------------
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-2"
  }
}

# ---------------------------------------------------------------------------
# Private subnet in AZ-1 — hosts EC2 app servers and the RDS primary.
# No public IPs are assigned; these resources are not directly reachable from
# the internet.
# ---------------------------------------------------------------------------
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-private-1"
  }
}

# ---------------------------------------------------------------------------
# Private subnet in AZ-2 — second private subnet required by the RDS subnet
# group (multi-AZ capable) and ASG spread.
# ---------------------------------------------------------------------------
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-private-2"
  }
}

# ---------------------------------------------------------------------------
# Internet Gateway — the door between your VPC and the public internet.
# Without this, nothing in the VPC can send or receive internet traffic.
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ---------------------------------------------------------------------------
# Elastic IP for the NAT Gateway — a static public IP address that the NAT
# Gateway uses when private instances talk outward to the internet.
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"
}

# ---------------------------------------------------------------------------
# NAT Gateway — sits in the public subnet and lets private EC2 instances
# download packages and reach the internet OUTBOUND ONLY.  Inbound connections
# from the internet cannot reach those private instances.
# ---------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  subnet_id     = aws_subnet.public_1.id
  allocation_id = aws_eip.nat.id

  tags = {
    Name = "${var.project_name}-nat"
  }

  # The NAT Gateway depends on the IGW being attached first.
  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------------------
# Public route table — routes 0.0.0.0/0 (all internet traffic) through the
# Internet Gateway.  Associated with both public subnets.
# ---------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate the public route table with public subnet 1.
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# Associate the public route table with public subnet 2.
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Private route table — routes outbound internet traffic through the NAT
# Gateway so private instances can reach the internet without being exposed.
# ---------------------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate the private route table with private subnet 1.
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

# Associate the private route table with private subnet 2.
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}
