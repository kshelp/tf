# 1단계: 루트 모듈에 직접 정의한 리소스
resource "local_file" "web" {
  content  = "web server config"
  filename = "${path.module}/web.conf"
}
