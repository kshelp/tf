terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # 이 코드는 state 버킷 자체를 만드므로 로컬 State를 쓴다(부트스트랩).
}

# IAM 사용자·역할·정책을 만들 수 있는 관리자 자격 증명으로 실행한다.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "ch05-deployers"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
