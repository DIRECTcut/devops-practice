terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
  # No default - must be provided via terraform.tfvars or -var flag
}

# Data source for latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group
resource "aws_security_group" "nginx_server" {
  name        = "nginx-ssh-2222-sg"
  description = "Security group for nginx server with SSH on port 2222"

  # SSH on port 2222
  ingress {
    description = "SSH on port 2222"
    from_port   = 2222
    to_port     = 2222
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP on port 80
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nginx-server-sg"
  }
}

# User data script - load from external file
locals {
  user_data = templatefile("${path.module}/scripts/user-data.sh", {
    ssh_public_key = var.ssh_public_key
  })
}

# IAM role for Systems Manager
resource "aws_iam_role" "ec2_ssm_role" {
  name = "nginx-server-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "nginx-server-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# EC2 Instance
resource "aws_instance" "nginx_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.nginx_server.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(local.user_data)

  tags = {
    Name = "nginx-web-server"
  }
}

# Outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.nginx_server.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.nginx_server.public_ip
}

output "public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.nginx_server.public_dns
}

output "website_url" {
  description = "URL for the nginx homepage"
  value       = "http://${aws_instance.nginx_server.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -p 2222 ec2-user@${aws_instance.nginx_server.public_ip}"
}