// 한 줄 주석 방법1
# 한 줄 주석 방법2
/*
여러 줄
주석
*/

variable "project" {
  default = "terraform-101"
}

locals {
  key1     = "value1"     # = 를 기준으로 키와 값을 구분한다
  myStr    = "TF ♡ UTF-8" # UTF-8 문자를 지원한다
  multiStr = <<-EOT
    Multi
    Line
    String
  EOT

  boolean1    = true # bool
  boolean2    = false
  decimal     = 123    # 10진수
  hexadecimal = "0xD5" # 0x로 시작하는 문자열 (숫자로 쓰려면 parseint 사용)
  scientific  = 1e10   # 과학 표기법

  interpolation = "project = ${var.project}"                           # 문자열 보간
  directive     = "%{if local.boolean1}enabled%{else}disabled%{endif}" # 템플릿 지시자

  myprojectname = format("%s is myproject name", var.project) # 함수 호출
  env           = var.project == "" ? "unknown" : "dev"       # 3항 연산자
}

output "hcl_examples" {
  value = {
    key1          = local.key1
    myStr         = local.myStr
    multiStr      = local.multiStr
    decimal       = local.decimal
    hex_to_number = parseint(trimprefix(local.hexadecimal, "0x"), 16)
    scientific    = local.scientific
    interpolation = local.interpolation
    directive     = local.directive
    myprojectname = local.myprojectname
    env           = local.env
  }
}
