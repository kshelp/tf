resource "local_file" "abc" {
  content  = "abc!"
  filename = "${path.module}/abc.txt"
}

# 3.1.4 실습 2단계에서 주석을 풀고 다시 apply 한다.
# resource "local_file" "def" {
#   content  = "def!"
#   filename = "${path.module}/def.txt"
# }
