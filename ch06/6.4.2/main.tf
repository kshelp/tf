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

# 공개 레지스트리 모듈: <네임스페이스>/<이름>/<프로바이더>
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "registry-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = false # 실습 비용 절감

  tags = {
    ManagedBy = "terraform"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

# 사설 레지스트리 모듈: <호스트>/<조직>/<이름>/<프로바이더>
# module "ecs_instance" {
#   source  = "app.terraform.io/<ORG>/ecs-instance/alicloud"
#   version = ">= 2.9.0"
# }
