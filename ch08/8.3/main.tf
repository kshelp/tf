terraform {
  # GitHub Actions는 실행마다 새 러너를 쓰므로 State를 HCP Terraform에 저장한다.
  # 워크스페이스 실행 모드를 Local로 바꾸면 러너에서 plan/apply가 실행된다.
  cloud {
    organization = "<MY_ORG>"
    workspaces {
      name = "terraform-aws-github-action"
    }
  }

  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_vpc" "hashicat" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true
  tags = {
    name        = "${var.prefix}-vpc-${var.region}"
    environment = var.environment
  }
}

resource "aws_subnet" "hashicat" {
  vpc_id                  = aws_vpc.hashicat.id
  cidr_block              = var.subnet_prefix
  map_public_ip_on_launch = true
  tags                    = { name = "${var.prefix}-subnet" }
}

resource "aws_internet_gateway" "hashicat" {
  vpc_id = aws_vpc.hashicat.id
  tags   = { name = "${var.prefix}-igw" }
}

resource "aws_route_table" "hashicat" {
  vpc_id = aws_vpc.hashicat.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hashicat.id
  }
}

resource "aws_route_table_association" "hashicat" {
  subnet_id      = aws_subnet.hashicat.id
  route_table_id = aws_route_table.hashicat.id
}

resource "aws_security_group" "hashicat" {
  name   = "${var.prefix}-sg"
  vpc_id = aws_vpc.hashicat.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "hashicat" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.hashicat.id
  vpc_security_group_ids      = [aws_security_group.hashicat.id]
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/files/deploy_app.sh.tftpl", {
    prefix      = var.prefix
    environment = var.environment
  })
  tags = { Name = "${var.prefix}-hashicat", environment = var.environment }

  depends_on = [aws_route_table_association.hashicat]
}

resource "aws_eip" "hashicat" {
  instance = aws_instance.hashicat.id
  domain   = "vpc"
}
