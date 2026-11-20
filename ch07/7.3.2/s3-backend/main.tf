terraform {
  # 부분 구성(partial configuration): 환경마다 다른 값은 backend.hcl로 분리
  #   terraform init -backend-config=backend.hcl
  backend "s3" {
    key          = "ch07/s3-backend/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true # S3 네이티브 잠금 (Terraform 1.10+). DynamoDB 테이블 불필요
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

resource "aws_ssm_parameter" "hello" {
  name  = "/ch07/s3-backend/hello"
  type  = "String"
  value = "State is stored in S3"
}

output "parameter_arn" {
  value = aws_ssm_parameter.hello.arn
}
