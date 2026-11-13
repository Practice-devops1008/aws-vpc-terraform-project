
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create VPC
resource "aws_vpc" "VPC01" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "VPC01"
  }
}

# Create Public Subnet
resource "aws_subnet" "PublicSubnet" {
  vpc_id                  = aws_vpc.VPC01.id
  availability_zone       = "us-east-1a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet"
  }
}

# Create Private Subnet
resource "aws_subnet" "PrivateSubnet" {
  vpc_id                  = aws_vpc.VPC01.id
  availability_zone       = "us-east-1b"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "PrivateSubnet"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.VPC01.id

  tags = {
    Name = "IGW"
  }
}

# Create Public Route Table
resource "aws_route_table" "PublicRT" {
  vpc_id = aws_vpc.VPC01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }

  tags = {
    Name = "PublicRT"
  }
}

# Associate Public Route Table
resource "aws_route_table_association" "PublicRT" {
  subnet_id      = aws_subnet.PublicSubnet.id
  route_table_id = aws_route_table.PublicRT.id
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "EIP" {
  domain = "vpc"

  tags = {
    Name = "NAT-EIP"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "NAT" {
  allocation_id = aws_eip.EIP.id
  subnet_id     = aws_subnet.PublicSubnet.id

  tags = {
    Name = "NAT"
  }

  depends_on = [aws_internet_gateway.IGW]
}

# Create Private Route Table
resource "aws_route_table" "PrivateRT" {
  vpc_id = aws_vpc.VPC01.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT.id
  }

  tags = {
    Name = "PrivateRT"
  }
}

# Associate Private Route Table
resource "aws_route_table_association" "PrivateRT" {
  subnet_id      = aws_subnet.PrivateSubnet.id
  route_table_id = aws_route_table.PrivateRT.id
}

# Create Public Security Group
resource "aws_security_group" "PublicSG" {
  name        = "PublicSG"
  description = "Security group for public instance"
  vpc_id      = aws_vpc.VPC01.id

  # SSH - restrict this to your own public IP
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["49.36.120.25/32"]
  }

  # HTTP
  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PublicSG"
  }
}

# Create Private Security Group
resource "aws_security_group" "PrivateSG" {
  name        = "PrivateSG"
  description = "Security group for private instance"
  vpc_id      = aws_vpc.VPC01.id

  ingress {
    description = "Traffic from public subnet"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PrivateSG"
  }
}

# Create Public EC2 Instance
resource "aws_instance" "PublicInstance" {
  ami                         = "ami-096ef200a877f36af"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.PublicSubnet.id
  vpc_security_group_ids      = [aws_security_group.PublicSG.id]
  associate_public_ip_address = true
  key_name                    = "Jenkins"

  tags = {
    Name = "PublicInstance"
  }
}

# Create Private EC2 Instance
resource "aws_instance" "PrivateInstance" {
  ami                         = "ami-096ef200a877f36af"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.PrivateSubnet.id
  vpc_security_group_ids      = [aws_security_group.PrivateSG.id]
  associate_public_ip_address = false
  key_name                    = "Jenkins"

  tags = {
    Name = "PrivateInstance"
  }
}



