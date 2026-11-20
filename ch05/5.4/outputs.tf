output "vpc_id" {
  value = aws_vpc.mynet.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "public_subnet_ids" {
  value = [for k in sort(keys(local.public_subnets)) : aws_subnet.this[k].id]
}

output "private_subnet_ids" {
  value = [for k in sort(keys(local.private_subnets)) : aws_subnet.this[k].id]
}

output "server_private_ips" {
  value = { for k, v in aws_instance.server : k => v.private_ip }
}

output "security_group_ids" {
  value = {
    bastion = aws_security_group.bastion.id
    web_lb  = aws_security_group.web_lb.id
    web     = aws_security_group.web.id
    was_lb  = aws_security_group.was_lb.id
    was     = aws_security_group.was.id
    mysql   = aws_security_group.mysql.id
    redis   = aws_security_group.redis.id
  }
}

output "web_lb_dns_name" {
  description = "외부 ALB 주소 (브라우저 접속, 외부 DNS www CNAME 값)"
  value       = aws_lb.web.dns_name
}

output "was_lb_dns_name" {
  description = "내부 NLB 주소 (was.cloud.local)"
  value       = aws_lb.was.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.address
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "internal_dns" {
  value = {
    db    = aws_route53_record.db.fqdn
    redis = aws_route53_record.redis.fqdn
    was   = aws_route53_record.was.fqdn
  }
}
