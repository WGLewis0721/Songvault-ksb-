# networking.tf
# =============
# This file builds the network foundation everything else sits on.
# Think of it like this:
#   VPC          = Your private building in AWS
#   Subnets      = Floors in the building (public floors face the street, private floors are internal)
#   IGW          = The front door (connects public floors to the internet)
#   NAT Gateway  = A mail proxy (lets private floors send mail out but nobody can walk in)
#   Route Tables = The building directory (tells traffic which door to use)

# ---------------------------------------------------------------------------
# Gets the list of available data centers (Availability Zones) in our region.
# We use two AZs for high availability — if one has a problem, the other keeps running.
# ---------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------
# Our private network in AWS. Nothing inside can be reached from the internet
# unless we explicitly open a door. CIDR 10.0.0.0/16 gives us 65,536 private
# IP addresses to use for all our subnets.
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "${var.project_name}-vpc"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Public subnet in the first data center. Resources here get a public IP address.
# The ALB (load balancer) and NAT Gateway live here. App servers do NOT live here.
# ---------------------------------------------------------------------------
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name      = "${var.project_name}-public-1"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Public subnet in the second data center. The ALB needs to be in 2 data centers
# to be considered highly available. If AZ1 has an outage, AZ2 keeps serving traffic.
# ---------------------------------------------------------------------------
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name      = "${var.project_name}-public-2"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Private subnet in the first data center. No public IPs. App servers and the
# database live here. Attackers on the internet cannot reach these directly.
# ---------------------------------------------------------------------------
resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.101.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name      = "${var.project_name}-private-1"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Private subnet in the second data center. App servers spread across both
# private subnets so the app keeps running if one data center has an issue.
# ---------------------------------------------------------------------------
resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.102.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name      = "${var.project_name}-private-2"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# The front door of our VPC. Without this, nothing in our VPC can reach the
# internet and nothing from the internet can reach us. Public subnets use this.
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-igw"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# A static public IP address reserved for our NAT Gateway. EIP = Elastic IP.
# It stays the same even if the NAT Gateway is replaced.
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name      = "${var.project_name}-nat-eip"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Lets private EC2 instances reach the internet (to download Python packages)
# without having a public IP. Traffic goes: private EC2 → NAT Gateway → internet.
# Inbound connections from the internet are NOT allowed through the NAT Gateway.
# ---------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name      = "${var.project_name}-nat"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# The routing rule for public subnets: send all internet traffic through the IGW.
# 0.0.0.0/0 means "everything that isn't a local address".
# ---------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name      = "${var.project_name}-public-rt"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# Apply the public routing rule to public subnet 1.
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# Apply the public routing rule to public subnet 2.
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# The routing rule for private subnets: send outbound internet traffic through
# the NAT Gateway. This is how private EC2 instances install packages — they go
# out through NAT but nothing from the internet can come back in directly.
# ---------------------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name      = "${var.project_name}-private-rt"
    Project   = var.project_name
    Owner     = "student"
    ManagedBy = "terraform"
  }
}

# Apply the private routing rule to private subnet 1.
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

# Apply the private routing rule to private subnet 2.
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}
