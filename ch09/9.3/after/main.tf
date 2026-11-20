# 리팩터링 후: 변수·모듈로 분리하고 moved 블록으로 State 주소를 옮긴다.
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "common" {
  source = "../modules/common"
  prefix = var.environment
  tags   = local.common_tags
}

moved {
  from = aws_vpc.main
  to   = module.common.aws_vpc.this
}

moved {
  from = aws_subnet.private_a
  to   = module.common.aws_subnet.private["ap-northeast-2a"]
}

moved {
  from = aws_subnet.private_c
  to   = module.common.aws_subnet.private["ap-northeast-2c"]
}
