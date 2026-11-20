# dev 환경 루트 모듈. 디렉터리마다 독립된 State를 갖는다.
terraform {
  backend "s3" {
    key          = "ch08/envs/dev/terraform.tfstate" # 환경별로 다른 State 경로
    region       = "ap-northeast-2"
    use_lockfile = true
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
  default_tags {
    tags = { Environment = "dev", ManagedBy = "terraform" }
  }
}

module "network" {
  source = "../../modules/network"
  env    = "dev"
  cidr   = "10.10.0.0/16"
  azs    = ["ap-northeast-2a"]
}

output "vpc_id" {
  value = module.network.vpc_id
}
