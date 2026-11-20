# 선언형(Declarative) 방식: "무엇이" 있어야 하는지만 정의한다.
# 존재 여부 확인, 생성·변경·삭제 순서는 테라폼이 State와 비교해 결정한다.
terraform {
  required_version = ">= 1.6"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "servers" {
  type    = set(string)
  default = ["web", "was", "db"]
}

resource "local_file" "server" {
  for_each = var.servers
  content  = "server=${each.key}\n"
  filename = "${path.module}/out/${each.key}.txt"
}
