# TF_VAR_<이름> 환경 변수 실습
variable "greeting" {
  default = "hello"
}

resource "local_file" "env" {
  content  = "${var.greeting}, terraform"
  filename = "${path.module}/env.txt"
}

output "greeting" {
  value = var.greeting
}
