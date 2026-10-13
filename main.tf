# ShopLite AWS network foundation
# This first pass creates the core networking resources only.

terraform {
  required_version = ">= 1.5.0"

<<<<<<< HEAD
  backend "s3" {
    bucket  = "shoplite-terraform-state0"
    key     = "shoplite/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
=======
 
>>>>>>> cdd54b2 (FIrsir)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region where the ShopLite infrastructure will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used in resource naming and tags."
  type        = string
  default     = "shoplite"
}

<<<<<<< HEAD
variable "vpc_cidr" {
  description = "CIDR block for the ShopLite VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.10.1.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR block for the first private subnet in Availability Zone A."
  type        = string
  default     = "10.10.10.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for the second private subnet in Availability Zone B."
  type        = string
  default     = "10.10.11.0/24"
}

variable "instance_type" {
  description = "EC2 instance type to use for the demo instances."
  type        = string
  default     = "t3.micro"
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# Fetch available AZs so we can place the subnets across distinct AZs.
data "aws_availability_zones" "available" {
  state = "available"
}

# Use the latest Ubuntu 22.04 LTS AMI for both demo instances.
data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# VPC for the ShopLite application.
resource "aws_vpc" "shoplite_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# Internet Gateway allows public subnet resources to reach the internet.
resource "aws_internet_gateway" "shoplite_igw" {
  vpc_id = aws_vpc.shoplite_vpc.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# Public subnet for internet-facing resources.
resource "aws_subnet" "shoplite_public_subnet" {
  vpc_id                  = aws_vpc.shoplite_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet"
    Type = "public"
  })
}

# First private subnet in a different AZ from the second private subnet.
resource "aws_subnet" "shoplite_private_subnet_a" {
  vpc_id            = aws_vpc.shoplite_vpc.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-subnet-a"
    Type = "private"
  })
}

# Second private subnet in a separate Availability Zone.
resource "aws_subnet" "shoplite_private_subnet_b" {
  vpc_id            = aws_vpc.shoplite_vpc.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-subnet-b"
    Type = "private"
  })
}

# Route table for public subnet. Default route sends traffic to the Internet Gateway.
resource "aws_route_table" "shoplite_public_rt" {
  vpc_id = aws_vpc.shoplite_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.shoplite_igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
    Type = "public"
  })
}

# Private route table for subnet A. No default route is attached here yet.
resource "aws_route_table" "shoplite_private_rt_a" {
  vpc_id = aws_vpc.shoplite_vpc.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-rt-a"
    Type = "private"
  })
}

# Private route table for subnet B. No default route is attached here yet.
resource "aws_route_table" "shoplite_private_rt_b" {
  vpc_id = aws_vpc.shoplite_vpc.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-rt-b"
    Type = "private"
  })
}

# Associate the public subnet with the public route table.
resource "aws_route_table_association" "shoplite_public_assoc" {
  subnet_id      = aws_subnet.shoplite_public_subnet.id
  route_table_id = aws_route_table.shoplite_public_rt.id
}

# Elastic IP and NAT Gateway provide outbound internet access for private subnets.
resource "aws_eip" "shoplite_nat_eip" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "shoplite_nat" {
  allocation_id = aws_eip.shoplite_nat_eip.id
  subnet_id     = aws_subnet.shoplite_public_subnet.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat"
  })

  depends_on = [aws_internet_gateway.shoplite_igw]
}

# Route private subnet outbound traffic through the NAT Gateway.
resource "aws_route" "shoplite_private_route_a" {
  route_table_id         = aws_route_table.shoplite_private_rt_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.shoplite_nat.id
}

resource "aws_route" "shoplite_private_route_b" {
  route_table_id         = aws_route_table.shoplite_private_rt_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.shoplite_nat.id
}

# Associate the first private subnet with its private route table.
resource "aws_route_table_association" "shoplite_private_assoc_a" {
  subnet_id      = aws_subnet.shoplite_private_subnet_a.id
  route_table_id = aws_route_table.shoplite_private_rt_a.id
}

# Associate the second private subnet with its private route table.
resource "aws_route_table_association" "shoplite_private_assoc_b" {
  subnet_id      = aws_subnet.shoplite_private_subnet_b.id
  route_table_id = aws_route_table.shoplite_private_rt_b.id
}

# Trusted SSH ingress CIDR for bastion/public access.
variable "trusted_ssh_cidr" {
  description = "CIDR block allowed to SSH into the bastion/public server. Use a trusted single IP or network, not 0.0.0.0/0."
  type        = string
  default     = "203.0.113.10/32"
}

# Bastion/public server security group for internet-facing SSH access.
resource "aws_security_group" "shoplite_bastion_sg" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH from a trusted source to the bastion/public server."
  vpc_id      = aws_vpc.shoplite_vpc.id

  ingress {
    description = "Allow SSH from a trusted CIDR only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_ssh_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-bastion-sg"
    Type = "public"
  })
}

# Security group for private k3s nodes. SSH is restricted to the bastion SG.
resource "aws_security_group" "shoplite_private_k3s_sg" {
  name        = "${var.project_name}-private-k3s-sg"
  description = "Allow SSH only from the bastion security group to private k3s nodes."
  vpc_id      = aws_vpc.shoplite_vpc.id

  ingress {
    description     = "Allow SSH from bastion security group only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.shoplite_bastion_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-k3s-sg"
    Type = "private"
  })
}

# Public EC2 instance in the public subnet.
resource "aws_instance" "shoplite_public_instance" {
  ami                         = data.aws_ami.ubuntu_22_04.id
  key_name                    = "key"
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.shoplite_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.shoplite_bastion_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Update system packages
              sudo apt-get update -y
              sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

              # --- INSTALL DOCKER ---
              sudo mkdir -p /etc/at/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

              sudo apt-get update -y
              sudo apt-get install -y docker-ce docker-ce-cli containerd.io
              sudo systemctl enable docker
              sudo systemctl start docker

              # Add default ubuntu user to docker group
              sudo usermod -aG docker ubuntu

              # --- PULL AND RUN DOCKER CONTAINER ---
              # Replace 'nginx:latest' with your target Docker image (e.g., username/repository:tag)
              
              sudo docker pull andyelie/shoplite:latest
              
              sudo docker run -d --name my_app --restart always -p 8000:8000 andyelie/shoplite:latest
              EOF

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-instance"
    Type = "public"
  })
}

# Private EC2 instance in the private subnet.
resource "aws_instance" "shoplite_private_instance" {
  ami                    = data.aws_ami.ubuntu_22_04.id
  key_name               = "key"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.shoplite_private_subnet_a.id
  vpc_security_group_ids = [aws_security_group.shoplite_private_k3s_sg.id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-instance"
    Type = "private"
  })
=======
resource "aws_s3_bucket" "shoplite_state" {
  bucket = "${var.project_name}-terraform-state"

  tags = {
    Name        = "${var.project_name}-terraform-state"
    Environment = "production"
  }
}

resource "aws_s3_bucket_acl" "shoplite_state" {
  bucket = aws_s3_bucket.shoplite_state.id
  acl    = "private"
>>>>>>> cdd54b2 (FIrsir)
}

