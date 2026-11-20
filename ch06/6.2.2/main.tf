# 6.2.2 자식 모듈 호출: 같은 모듈을 입력 값만 바꿔 여러 번 사용한다.
module "mypw1" {
  source = "../modules/terraform-random-pwgen"
}

module "mypw2" {
  source = "../modules/terraform-random-pwgen"
  isDB   = true
}

output "mypw1" {
  value = module.mypw1
}

output "mypw2" {
  value = module.mypw2
}
