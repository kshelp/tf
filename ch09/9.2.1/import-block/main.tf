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

variable "legacy_sg_id" {
  type        = string
  description = "콘솔에서 만든 보안 그룹 ID (sg-...)"
}

# 1) import 블록: plan으로 미리 확인하고 apply로 State에 등록한다(1.5+).
import {
  to = aws_security_group.legacy
  id = var.legacy_sg_id
}

# 2) 리소스 블록: 실제 설정과 같게 작성해야 plan이 "0 to change"가 된다.
resource "aws_security_group" "legacy" {
  name        = "legacy-web-sg"
  description = "created in console"

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
