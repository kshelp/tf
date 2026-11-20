# AI가 생성한 코드를 사람이 정한 요구사항으로 검증한다.
mock_provider "aws" {}

run "subnets_per_requirement" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "퍼블릭/프라이빗 서브넷은 각 2개여야 한다."
  }

  assert {
    condition     = aws_subnet.public["ap-northeast-2a"].cidr_block == "10.0.0.0/24"
    error_message = "첫 번째 퍼블릭 서브넷 CIDR이 요구사항과 다르다."
  }

  assert {
    condition     = aws_subnet.private["ap-northeast-2c"].cidr_block == "10.0.11.0/24"
    error_message = "두 번째 프라이빗 서브넷 CIDR이 요구사항과 다르다."
  }
}

# plan 단계에서 코드에 쓰지 않은 선택 인수는 null이므로 coalesce로 기본값(false)을 채워 비교한다.
run "private_subnets_have_no_public_ip" {
  command = plan

  assert {
    condition     = alltrue([for s in aws_subnet.private : coalesce(s.map_public_ip_on_launch, false) == false])
    error_message = "프라이빗 서브넷은 공인 IP를 자동 할당하면 안 된다."
  }
}

run "reject_unknown_environment" {
  command = plan

  variables {
    environment = "test"
  }

  expect_failures = [var.environment]
}
