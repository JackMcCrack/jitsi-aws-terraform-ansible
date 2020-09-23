####
#	Setup a AWS EC2 Instance via Terraform and install Jitis-Meet via Ansible
####

# Subnet for Jits instance(s)
resource "aws_subnet" "jitsi-meet-net" {
  vpc_id = aws_vpc.ip_range.id
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
  cidr_block = var.aws_subnet_cidr_block
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
  provisioner "local-exec" {
    command = "curl -s 'https://${var.dns_username}:${var.dns_password}@domains.google.com/nic/update?hostname=${var.jitsi_vhost}&myip=${aws_instance.jitsi-instance.public_ip}'"
  }
  provisioner "local-exec" {
    command = "sleep 120; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${aws_instance.jitsi-instance.public_ip},' -e 'servername=${var.jitsi_vhost}' ansible/jitsi-playbook.yaml"
  }
  tags = {
    name = "jitsi-meet"
  }
}


