# common + eks 모듈 조합 예시 (EKS는 시간당 과금이 크므로 plan까지만 확인 권장)
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

module "common" {
  source = "../modules/common"
  prefix = "dev"
}

module "eks" {
  source     = "../modules/eks"
  prefix     = "dev"
  vpc_id     = module.common.vpc_id
  subnet_ids = module.common.private_subnet_ids
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
