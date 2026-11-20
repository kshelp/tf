# State를 저장할 S3 버킷을 만든다. 이 구성의 State는 로컬에 둔다(닭과 달걀 문제).
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

variable "bucket_name" {
  type        = string
  description = "전역에서 고유한 S3 버킷 이름 (예: tfstate-<계정ID>-apne2)"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true # State 버킷을 실수로 삭제하지 않도록 보호
  }
}

# 버전 관리: State가 덮어써지거나 손상돼도 이전 버전으로 복구
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 서버 측 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 퍼블릭 접근 차단
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}
