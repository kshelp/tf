# 하나의 State에 앱과 DB가 함께 있다.
resource "local_file" "app" {
  content  = "app"
  filename = "${path.module}/app.txt"
}

resource "local_file" "db" {
  content  = "db (오래 유지되는 리소스)"
  filename = "${path.module}/db.txt"
}
