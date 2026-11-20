# 2단계(방법 A): 리소스를 모듈로 옮긴 코드. State는 CLI(state mv)로 옮긴다.
#   terraform state mv local_file.web module.web.local_file.this
module "web" {
  source   = "../modules/file"
  content  = "web server config"
  filename = "${path.module}/web.conf"
}
