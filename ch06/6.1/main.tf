# 루트 모듈: 자식 모듈(terraform-random-pwgen)을 두 번 호출한다.
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
