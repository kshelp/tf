variable "prefix" {
  default = "hello"
}

variable "env" {
  default = "dev"
}

locals {
  name    = "terraform"
  content = "${var.prefix}, ${local.name}" # local에서 다른 local 참조 가능

  # 반복해서 쓰는 값을 한 곳에서 정의
  common_tags = {
    Environment = var.env
    ManagedBy   = "terraform"
  }

  # 계산 결과를 이름으로 재사용
  is_prod   = var.env == "prod"
  file_mode = local.is_prod ? "0400" : "0644"
}

resource "local_file" "abc" {
  content         = local.content
  filename        = "${path.module}/abc.txt"
  file_permission = local.file_mode
}

output "common_tags" {
  value = local.common_tags
}
