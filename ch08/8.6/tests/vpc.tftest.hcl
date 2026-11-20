# 실제 AWS를 호출하지 않도록 프로바이더를 모의(mock)한다. 자격증명 없이 실행 가능
mock_provider "aws" {}

# 모든 run 블록에 공통으로 적용되는 변수
variables {
  prefix      = "unit"
  environment = "dev"
}

run "check_env_tag" {
  command = plan

  assert {
    condition     = aws_vpc.hashicat.tags.environment == "dev"
    error_message = "environment 태그가 올바르지 않다."
  }

  assert {
    condition     = aws_vpc.hashicat.tags.name == "unit-vpc"
    error_message = "name 태그는 <prefix>-vpc 형식이어야 한다."
  }
}

run "subnet_cidr_is_derived_from_vpc" {
  command = plan

  variables {
    address_space = "10.50.0.0/16"
  }

  assert {
    condition     = aws_subnet.hashicat.cidr_block == "10.50.10.0/24"
    error_message = "서브넷 CIDR은 VPC CIDR의 10번째 /24여야 한다."
  }
}

run "invalid_env" {
  command = plan

  variables {
    environment = "test"
  }

  # 변수 검증이 실패하는 것이 기대 결과다
  expect_failures = [var.environment]
}

run "apply_with_mock" {
  command = apply # mock 프로바이더가 가짜 ID를 만들어 준다

  assert {
    condition     = output.vpc_id != ""
    error_message = "vpc_id output이 비어 있다."
  }
}
