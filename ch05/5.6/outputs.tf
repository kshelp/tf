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

output "security_group_ids" {
  value = {
    bastion = aws_security_group.bastion.id
    web_lb  = aws_security_group.web_lb.id
    web     = aws_security_group.web.id
    was_lb  = aws_security_group.was_lb.id
    was     = aws_security_group.was.id
    mysql   = aws_security_group.mysql.id
    redis   = aws_security_group.redis.id
    cluster = local.cluster_sg_id
  }
}

# ---------- EKS ----------
output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "kubeconfig_command" {
  description = "실습 PC에서 kubectl을 설정하는 명령"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}"
}

output "node_groups" {
  description = "노드 그룹별 오토 스케일링 그룹 (5.4의 web1·web2, was1·was2 대신)"
  value       = { for k, v in aws_eks_node_group.this : k => v.resources[0].autoscaling_groups[0].name }
}

# ---------- 로드 밸런서 / 데이터 ----------
output "web_url" {
  description = "브라우저 접속 주소"
  value       = "http://${aws_lb.web.dns_name}"
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
