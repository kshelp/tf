output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID (AZ => ID)"
  value       = { for az, s in aws_subnet.public : az => s.id }
}

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID (AZ => ID)"
  value       = { for az, s in aws_subnet.private : az => s.id }
}

output "nat_public_ip" {
  description = "NAT 게이트웨이 공인 IP"
  value       = aws_eip.nat.public_ip
}
