terraform {
  required_version = ">= 1.6.0" # 테라폼 CLI 버전 제약

  required_providers { # 프로바이더 소스와 버전 제약
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }

  # State 저장 위치. 생략하면 local 백엔드(./terraform.tfstate)를 사용한다.
  backend "local" {
    path = "state/terraform.tfstate"
  }

  # HCP Terraform을 사용할 때는 backend 대신 cloud 블록을 사용한다(동시 사용 불가).
  # cloud {
  #   organization = "<MY_ORG_NAME>"
  #   workspaces {
  #     name = "my-first-workspace"
  #   }
  # }
}

resource "random_pet" "name" {}

resource "local_file" "hello" {
  content  = "hello, ${random_pet.name.id}"
  filename = "${path.module}/hello.txt"
}
