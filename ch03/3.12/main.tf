variable "sensitive_content" {
  default   = "secret"
  sensitive = true
}

resource "local_file" "foo" {
  content  = upper(var.sensitive_content)
  filename = "${path.module}/foo.bar"

  # 1) 생성 직후 실행. 민감 값이 포함되면 출력이 숨겨진다.
  provisioner "local-exec" {
    command = "echo The content is ${self.content}"
  }

  # 2) 실패해도 계속 진행
  provisioner "local-exec" {
    command    = "abc"
    on_failure = continue
  }

  # 3) 삭제 시점에만 실행
  provisioner "local-exec" {
    when    = destroy
    command = "echo The deleting filename is ${self.filename}"
  }
}

# 환경 변수와 인터프리터 지정
resource "local_file" "bar" {
  content  = "bar!"
  filename = "${path.module}/bar.txt"

  provisioner "local-exec" {
    command     = "echo \"$FILE was created\" >> provision.log"
    interpreter = ["/bin/bash", "-c"]
    working_dir = path.module
    environment = {
      FILE = self.filename
    }
  }
}
