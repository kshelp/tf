terraform {
  # 7.4 실습: 자신의 HCP Terraform 조직으로 바꾼 뒤 terraform init
  cloud {
    organization = "<MY_ORG>"
    workspaces {
      name = "terraform-aws-collaboration"
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

  default_tags {
    tags = {
      Owner       = var.prefix
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_vpc" "app" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true
  tags                 = { Name = "${var.prefix}-vpc-${var.region}" }
}

resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = var.subnet_prefix
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.prefix}-subnet" }
}

resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id
  tags   = { Name = "${var.prefix}-igw" }
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.app.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app.id
  }
  tags = { Name = "${var.prefix}-rt" }
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.app.id
}

resource "aws_security_group" "app" {
  name   = "${var.prefix}-sg"
  vpc_id = aws_vpc.app.id

  ingress {
    description = "HTTP"
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
  tags = { Name = "${var.prefix}-sg" }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.app.id
  vpc_security_group_ids = [aws_security_group.app.id]

  # 부팅 시 웹 서버 설치. 템플릿 값이 바뀌면 인스턴스를 교체한다.
  user_data = templatefile("${path.module}/files/deploy_app.sh.tftpl", {
    prefix      = var.prefix
    environment = var.environment
    message     = var.message
  })
  user_data_replace_on_change = true

  tags = { Name = "${var.prefix}-app" }

  depends_on = [aws_route_table_association.app]
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
  tags     = { Name = "${var.prefix}-eip" }
}
