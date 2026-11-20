resource "local_file" "abc" {
  content  = "abc123"
  filename = "${path.module}/abc.txt"
}

output "file_id" {
  description = "파일 내용의 SHA1 해시(리소스 ID)"
  value       = local_file.abc.id
}

output "file_abspath" {
  description = "생성된 파일의 절대 경로"
  value       = abspath(local_file.abc.filename)
}

output "file_info" { # 여러 값을 객체로 묶어 출력
  value = {
    name = basename(local_file.abc.filename)
    size = length(local_file.abc.content)
  }
}

output "secret" {
  value     = "p@ssw0rd"
  sensitive = true # terraform output에서 <sensitive>로 표시, -raw/-json으로만 확인
}
