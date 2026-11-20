# 3.4 리소스: 기본 문법, 참조, 메타인수(depends_on, lifecycle)
resource "local_file" "abc" {
  content  = "123!"
  filename = "${path.module}/abc.txt"
}

# 암시적 종속성: 다른 리소스의 속성을 참조하면 생성 순서가 자동으로 결정된다.
resource "local_file" "def" {
  content  = "abc.txt의 내용: ${local_file.abc.content}"
  filename = "${path.module}/def.txt"
}

# 명시적 종속성: 참조 관계가 없지만 순서가 필요할 때 depends_on을 사용한다.
resource "local_file" "ghi" {
  content    = "ghi!"
  filename   = "${path.module}/ghi.txt"
  depends_on = [local_file.def]
}

# lifecycle: 수명주기 제어
resource "local_file" "lifecycle" {
  content  = "lifecycle example"
  filename = "${path.module}/lifecycle.txt"

  lifecycle {
    create_before_destroy = false # true면 새 리소스를 먼저 만들고 기존 리소스를 삭제
    prevent_destroy       = false # true면 이 리소스를 삭제하는 plan을 오류로 막는다
    ignore_changes        = []    # 예: [content] → content 변경을 무시
  }
}

# lifecycle precondition/postcondition (1.2+)
variable "file_name" {
  default = "step0.txt"
}

resource "local_file" "checked" {
  content  = "checked!"
  filename = "${path.module}/${var.file_name}"

  lifecycle {
    precondition {
      condition     = endswith(var.file_name, ".txt")
      error_message = "file_name은 .txt로 끝나야 한다."
    }
    postcondition {
      condition     = self.content != ""
      error_message = "파일 내용이 비어 있으면 안 된다."
    }
  }
}
