terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# 기본 프로바이더: 싱가포르
provider "aws" {
  region = "ap-southeast-1"
}

# 별칭 프로바이더: 서울
provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

# AMI ID는 리전마다 다르므로 리전별로 조회한다.
data "aws_ami" "al2023_default" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_ami" "al2023_seoul" {
  provider    = aws.seoul
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "singapore" {
  ami           = data.aws_ami.al2023_default.id
  instance_type = "t3.micro"
  tags          = { Name = "multi-region-singapore" }
}

resource "aws_instance" "seoul" {
  provider      = aws.seoul
  ami           = data.aws_ami.al2023_seoul.id
  instance_type = "t3.micro"
  tags          = { Name = "multi-region-seoul" }
}

output "instances" {
  value = {
    singapore = aws_instance.singapore.availability_zone
    seoul     = aws_instance.seoul.availability_zone
  }
}
