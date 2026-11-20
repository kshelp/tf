# 5.2 State 동기화 실습
# 1) length를 16 → 20으로 바꾸고 plan: 교체(-/+) 계획 확인
resource "random_password" "password" {
  length           = 20  #16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?/"
}

# 2) apply 후 hello.txt를 직접 삭제하고 plan: 재생성 계획 확인
resource "local_file" "hello" {
  content  = "Hello, State!"
  filename = "${path.module}/hello.txt"
}
