# IP ranges
resource "aws_vpc" "ip_range" {
  cidr_block = var.aws_vpc_ip_range_cidr_block
  assign_generated_ipv6_cidr_block = true
}

# Gateway
resource "aws_internet_gateway" "default_gw" {
  vpc_id = aws_vpc.ip_range.id
  tags = {
    Name = "default-gw"
  }
}

# Routes
resource "aws_route_table" "route" {
  vpc_id = aws_vpc.ip_range.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default_gw.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.default_gw.id
  }
}

