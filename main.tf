####
#	Setup a AWS EC2 Instance via Terraform and install Jitis-Meet via Ansible
####

# version 20200919-2

variable "aws_key_name" {
  type = string
  default = "test-deleteme" # Name of your SSH Key pair
}
variable "aws_key_file" {
  type = string
  default = "~/.ssh/id_rsa.aws" # Name of your SSH Key pair
}
variable "aws_region" {
  type = string
  default = "ap-northeast-1" # Tokyo
}
variable "aws_availability_zone" {
  type = string
  default = "a" # in Tokyo currently available: a, c, d
}



#fetch aws credentials from enviroment variables (see run.sh)
variable "aws_akey" {
  type = string
  validation {
    condition     = length(var.aws_akey) > 0
    error_message = "Accesskey seems invalid!"
  }
}
variable "aws_skey" {
  type = string
  validation {
    condition     = length(var.aws_skey) > 0
    error_message = "Secretkey seems invalid!"
  }
}



# AWS Provider
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_akey
  secret_key = var.aws_skey
}

# IP ranges 
resource "aws_vpc" "ip_range" {
  cidr_block = "10.171.234.0/24"		#random ipv4 local net
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

# Subnet for Jits instance(s)
resource "aws_subnet" "jitsi-meet-net" {
  vpc_id = aws_vpc.ip_range.id
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
  cidr_block = "10.171.234.16/28"
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block = cidrsubnet(aws_vpc.ip_range.ipv6_cidr_block, 8, 1)
  tags = {
    name = "Jitsi_Meet"
  }
}

# assing routes to subnet
resource "aws_route_table_association" "jitsi-meet-net_route" {
  subnet_id      = aws_subnet.jitsi-meet-net.id
  route_table_id = aws_route_table.route.id
}



# Security Group aka Firewall
#INCOMING
resource "aws_security_group" "ssh" {
  name = "allow ssh"
  vpc_id =      aws_vpc.ip_range.id
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    name = "ssh allowed"
  }
}
resource "aws_security_group" "webserver" {
  name = "allow http and https"
  vpc_id =      aws_vpc.ip_range.id
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    name = "webserver ports allowed"
  }
}
resource "aws_security_group" "jitsi" {
  name =        "allow jitsi"
  description = "allow traffic to jitis"
  vpc_id =      aws_vpc.ip_range.id

  ingress {
    description = "jitsi-jvb-tcp"
    from_port   = 4443
    to_port     = 4443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description = "jitsi-jvb-udp"
    from_port   = 10000
    to_port     = 10000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    name = "jitis ports allowed"
  }
}
resource "aws_security_group" "ping" {
  name =        "allow icmp and icmpv6 echo requests"
  vpc_id =      aws_vpc.ip_range.id
  ingress {
    description = "icmp echo request (ping)"
    protocol    = "icmp"
    from_port   = 8
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "icmpv6 echo request (ping6)"
    protocol    = "icmpv6"
    from_port   = 128
    to_port     = 0
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    name = "icmp echo request allowed"
  }
}
#OUTGOING (allow everything)
#FIXME: allow only required ports / by service
resource "aws_security_group" "output" {
  name =        "allow all output"
  vpc_id =      aws_vpc.ip_range.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    name = "all output allowed"
  }
}



resource "aws_network_interface" "jitsi-nic" {
  subnet_id = aws_subnet.jitsi-meet-net.id
  security_groups = [ 
    aws_security_group.ssh.id, 
    aws_security_group.webserver.id, 
    aws_security_group.jitsi.id, 
    aws_security_group.ping.id, 
    aws_security_group.output.id 
  ]
}

resource "aws_eip" "jitsi_public_ip" {
  vpc               = true
  network_interface = aws_network_interface.jitsi-nic.id
  depends_on = [
    aws_internet_gateway.default_gw
  ]
}

resource "aws_instance" "jitsi-instance" {
  #ipv6_address_count = 1
  ami               = "ami-06b258aac2ae736c2" 	# ubuntu 20.04 ARM64
  instance_type     = "t4g.micro"		# ARM (free trail: https://aws.amazon.com/de/blogs/aws/new-t4g-instances-burstable-performance-powered-by-aws-graviton2/)
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.jitsi-nic.id
  }
  depends_on = [
    aws_internet_gateway.default_gw
  ]
  key_name          = var.aws_key_name
  tags = {
    name = "jitsi-meet"
  }
}



output "server_public_ip4" {
  value = aws_instance.jitsi-instance.public_ip
}
output "server_public_ip6" {
  value = aws_instance.jitsi-instance.ipv6_addresses
}

output "run_ansible" {
  value = "echo -e '[jitsi]\n${aws_instance.jitsi-instance.public_ip}\n\n[jitsi:vars]\nansible_ssh_private_key_file=${var.aws_key_file}' >ansible/hosts;  sleep 120; ansible-playbook -i ansible/hosts ansible/jitsi-playbook.yml"
}
