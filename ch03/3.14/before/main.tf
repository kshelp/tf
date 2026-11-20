# 1단계: 리소스 이름이 a인 상태로 apply 한다.
resource "local_file" "a" {
  content  = "foo!"
  filename = "${path.module}/foo.bar"
}

output "file_content" {
  value = local_file.a.content
}
