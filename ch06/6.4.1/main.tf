# 로컬 경로 모듈 소스: 반드시 ./ 또는 ../ 로 시작한다.
module "local_module" {
  source = "../modules/terraform-random-pwgen"
}

output "local_module" {
  value = module.local_module.id
}
