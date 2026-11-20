# 프로바이더는 루트 모듈에서 정의하고 자식 모듈에 전달한다.
provider "aws" {
  region = "us-west-1"
}

provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

module "ec2_california" {
  source = "../modules/terraform-aws-ec2" # 기본 프로바이더(us-west-1)를 물려받는다
}

module "ec2_seoul" {
  source = "../modules/terraform-aws-ec2"
  providers = {
    aws = aws.seoul # 모듈 안의 aws ← 루트의 aws.seoul
  }
  instance_type = "t3.micro"
  instance_name = "multi-provider-example"
}
