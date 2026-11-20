# 생산자(producer): 네트워크 팀의 구성. output으로 값을 공개한다.
terraform {
  backend "s3" {
    key          = "ch07/network/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_vpc" "main" {
  cidr_block = "10.20.0.0/16"
  tags       = { Name = "shared-network" }
}

resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = "ap-northeast-2a"
  tags              = { Name = "shared-app-subnet" }
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "app_subnet_id" {
  value = aws_subnet.app.id
}
