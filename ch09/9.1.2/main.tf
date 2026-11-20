terraform {
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

data "aws_vpc" "default" {
  default = true
}

# 드리프트 실습 대상: 콘솔에서 태그나 인바운드 규칙을 바꿔 본다.
resource "aws_security_group" "drift" {
  name        = "drift-demo-sg"
  description = "drift demo"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Name  = "drift-demo-sg"
    Owner = "platform-team"
  }
}
