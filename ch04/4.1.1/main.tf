terraform {
  required_providers {
    # 로컬 이름 http → hashicorp/http
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    # 같은 유형(http)의 다른 프로바이더는 로컬 이름을 다르게 지정한다.
    aws-http = {
      source  = "terraform-aws-modules/http"
      version = "~> 2.4"
    }
  }
}

# 리소스 유형 접두사(http)로 hashicorp/http가 자동 선택된다.
data "http" "example" {
  url = "https://checkpoint-api.hashicorp.com/v1/check/terraform"
  request_headers = {
    Accept = "application/json"
  }
}

# provider 메타인수로 다른 프로바이더를 지정한다.
data "http" "example2" {
  provider = aws-http
  url      = "https://checkpoint-api.hashicorp.com/v1/check/terraform"
  request_headers = {
    Accept = "application/json"
  }
}

output "latest_terraform_version" {
  value = jsondecode(data.http.example.response_body).current_version
}
