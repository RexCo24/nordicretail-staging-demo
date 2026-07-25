terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
}

# Create a VPC
resource "aws_vpc" "websrv_01" {
  cidr_block = "10.1.0.0/16"
}

resource "aws_subnet" "public_sub_01" {
  vpc_id     = aws_vpc.websrv_01.id
  cidr_block = "10.1.1.0/24"

  tags = {
    Name = "public_sub_01"
  }
}

resource "aws_subnet" "privat_sub_01" {
  vpc_id     = aws_vpc.websrv_01.id
  cidr_block = "10.1.2.0/24"

  tags = {
    Name = "privat_sub_01"
  }
}

resource "aws_internet_gateway" "websrv_igw_01" {
  vpc_id = aws_vpc.websrv_01.id

  tags = {
    Name = "websrv_igw_01"
  }
}

resource "aws_route_table" "websrv_rt_01" {
  vpc_id = aws_vpc.websrv_01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.websrv_igw_01.id
  }

  tags = {
    Name = "websrv_rt_01"
  }
}

resource "aws_route_table_association" "websrv_rt_assoc" {
  subnet_id      = aws_subnet.public_sub_01.id
  route_table_id = aws_route_table.websrv_rt_01.id
}

resource "aws_security_group" "websrv_sg_01" {
  name        = "Webserver-SG"
  description = "Allow TLS inbound SSH and HTTP"
  vpc_id      = aws_vpc.websrv_01.id

  tags = {
    Name = "websrv_allow"
  }
}

resource "aws_vpc_security_group_ingress_rule" "websrv_sg_ssh" {
  security_group_id = aws_security_group.websrv_sg_01.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "websrv_sg_http" {
  security_group_id = aws_security_group.websrv_sg_01.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.websrv_sg_01.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}



data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "websrv_instance_01" {
  ami                        = data.aws_ami.ubuntu.id
  instance_type              = "t3.micro"
  subnet_id                  = aws_subnet.public_sub_01.id
  vpc_security_group_ids = [aws_security_group.websrv_sg_01.id]

  user_data = <<-EOF
            #!/bin/bash
            apt update -y
            apt install nginx -y
            systemctl enable nginx
            systemctl start nginx
            EOF

  tags = {
    Name = "websrv_instance"
  }
}
