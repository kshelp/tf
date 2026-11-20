resource "local_file" "app" {
  content  = "app"
  filename = "${path.module}/app.txt"
}

# db는 다른 구성(State)으로 분리한다. 실제 리소스는 남기고 State에서만 제거
removed {
  from = local_file.db

  lifecycle {
    destroy = false
  }
}
