# 병합 대상 구성: 다른 State에서 제거(removed/state rm)한 리소스를 import 블록으로 가져온다.
terraform {
  required_version = ">= 1.6" # import 블록의 id에 변수 사용(1.6+)
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

variable "network_vpc_id" {
  type        = string
  description = "기존 network State에서 관리하던 VPC ID"
}

import {
  to = aws_vpc.network
  id = var.network_vpc_id
}

resource "aws_vpc" "network" {
  cidr_block = "10.20.0.0/16"
  tags       = { Name = "shared-network" }
}
