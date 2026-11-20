terraform {
  # CLI-driven 워크플로: 로컬 CLI로 명령하고 실행은 HCP Terraform(Remote 실행 모드)에서 한다.
  cloud {
    organization = "<MY_ORG>"
    workspaces {
      name = "terraform-aws-tfc-workflow"
    }
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

variable "prefix" {
  type = string
}

resource "aws_vpc" "this" {
  cidr_block = "10.30.0.0/16"
  tags       = { Name = "${var.prefix}-tfc-vpc" }
}

output "vpc_id" {
  value = aws_vpc.this.id
}
