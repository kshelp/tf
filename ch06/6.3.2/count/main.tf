provider "aws" {
  region = "ap-northeast-2"
}

# 같은 구성을 여러 개 만들 때는 count
module "ec2_seoul" {
  count         = 2
  source        = "../../modules/terraform-aws-ec2"
  instance_name = "count-ec2-${count.index}"
}

output "module_output" {
  value = module.ec2_seoul[*].private_ip
}
