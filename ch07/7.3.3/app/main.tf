# 소비자(consumer): 애플리케이션 팀의 구성. 네트워크 State의 output을 읽어 사용한다.
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

variable "state_bucket" {
  type        = string
  description = "네트워크 구성의 State가 저장된 S3 버킷"
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "ch07/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_security_group" "app" {
  name   = "app-sg"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id # 다른 State의 output 참조
}

output "network_outputs" {
  value = data.terraform_remote_state.network.outputs
}

# HCP Terraform을 쓴다면 tfe 프로바이더의 tfe_outputs 데이터 소스를 권장한다.
# data "tfe_outputs" "network" {
#   organization = "<MY_ORG>"
#   workspace    = "network"
# }
# vpc_id = data.tfe_outputs.network.values.vpc_id
