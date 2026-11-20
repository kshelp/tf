# 2단계: 이름을 a → b로 바꾸고 moved 블록으로 State 주소를 옮긴다.
resource "local_file" "b" {
  content  = "foo!"
  filename = "${path.module}/foo.bar"
}

moved {
  from = local_file.a
  to   = local_file.b
}

output "file_content" {
  value = local_file.b.content
}
