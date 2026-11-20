# 설치 확인용 최소 구성: 프로바이더 없이 init/plan/apply가 동작하는지 확인한다.
terraform {
  required_version = ">= 1.6"
}

output "hello" {
  value = "Hello, Terraform ${terraform.workspace}!"
}
