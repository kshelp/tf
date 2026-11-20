resource "local_file" "abc" {
  content  = "123!"
  filename = "${path.module}/abc.txt"
}

# 데이터 소스: 이미 존재하는 대상의 정보를 읽기만 한다.
data "local_file" "abc" {
  filename = local_file.abc.filename
}

resource "local_file" "def" {
  content  = data.local_file.abc.content # 읽어온 데이터를 참조
  filename = "${path.module}/def.txt"
}

output "abc_sha256" {
  value = data.local_file.abc.content_sha256
}
