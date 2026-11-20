output "id" {
  description = "인스턴스 ID"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "인스턴스 사설 IP"
  value       = aws_instance.this.private_ip
}

output "availability_zone" {
  description = "인스턴스가 배치된 가용 영역"
  value       = aws_instance.this.availability_zone
}
