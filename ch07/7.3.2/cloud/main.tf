terraform {
  # HCP Terraform을 State 백엔드로 사용한다. terraform login 후 init.
  cloud {
    organization = "<MY_ORG>" # 자신의 조직 이름으로 변경
    hostname     = "app.terraform.io"

    workspaces {
      name = "terraform-cloud-backend-demo"
    }
  }

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_pet" "name" {}

output "pet_name" {
  value = random_pet.name.id
}
