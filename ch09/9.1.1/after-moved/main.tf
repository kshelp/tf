# 2단계(방법 B): moved 블록으로 State 주소 이동을 코드에 기록한다.
module "web" {
  source   = "../modules/file"
  content  = "web server config"
  filename = "${path.module}/web.conf"
}

moved {
  from = local_file.web
  to   = module.web.local_file.this
}
