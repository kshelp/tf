# dynamic 블록: 리소스 안의 "중첩 블록"을 반복 생성한다.
# archive_file 데이터 소스의 source 블록을 파일 목록만큼 만든다.
terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

variable "files" {
  default = {
    "a.txt" = "hello a"
    "b.txt" = "hello b"
    "c.txt" = "hello c"
  }
}

data "archive_file" "zip" {
  type        = "zip"
  output_path = "${path.module}/files.zip"

  dynamic "source" {
    for_each = var.files
    content {
      filename = source.key
      content  = source.value
    }
  }
}

output "zip_size" {
  value = data.archive_file.zip.output_size
}
