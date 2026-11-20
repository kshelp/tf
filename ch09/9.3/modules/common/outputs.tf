output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  value       = [for s in aws_subnet.private : s.id]
}
