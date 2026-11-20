# 리소스 블록 없이 import 블록만 작성하고 코드를 자동 생성한다.
#   terraform plan -generate-config-out=generated.tf
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

import {
  to = aws_instance.legacy
  id = "i-0123456789abcdef0" # 가져올 인스턴스 ID로 변경
}
