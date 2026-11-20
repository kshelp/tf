output "app_url" {
  description = "웹 애플리케이션 주소"
  value       = "http://${aws_eip.app.public_ip}"
}

output "app_dns" {
  value = "http://${aws_eip.app.public_dns}"
}
