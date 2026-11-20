# 깃허브 모듈 소스. <OWNER>를 자신의 깃허브 계정으로 바꾼다.
# 저장소 안의 하위 디렉터리는 // 뒤에, 태그·브랜치는 ?ref= 로 지정한다.
provider "aws" {
  region = "ap-northeast-2"
}

module "ec2_seoul" {
  source = "github.com/<OWNER>/terraform-module-repo//terraform-aws-ec2?ref=v1.0.0"
}

output "module_output" {
  value = module.ec2_seoul.private_ip
}
