terraform {
  required_version = ">= 1.6.0" # 테라폼 CLI 자체의 버전 제약

  required_providers {
    random = {
      source  = "hashicorp/random" # = registry.terraform.io/hashicorp/random
      version = "~> 3.5"           # 3.5 이상 4.0 미만
    }
    local = {
      source  = "registry.terraform.io/hashicorp/local" # 호스트 주소를 명시한 형태
      version = ">= 2.4.0, != 2.4.1, < 3.0.0"           # 여러 조건(AND)
    }
  }
}

resource "random_pet" "name" {}

resource "local_file" "name" {
  content  = random_pet.name.id
  filename = "${path.module}/pet.txt"
}
