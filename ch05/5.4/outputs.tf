# =============================================================================
# outputs.tf — 출력 값
# -----------------------------------------------------------------------------
# apply가 끝나면 화면에 출력되고, 이후에도 다음 명령으로 다시 볼 수 있다.
#   terraform output                          # 전체
#   terraform output -raw bastion_public_ip   # 따옴표 없이 값만 (스크립트에서 사용)
#   terraform output -json                    # JSON 형식
# =============================================================================

# ---------- 네트워크 ----------
output "vpc_id" {
  value = aws_vpc.mynet.id
}

# 관리자 PC에서 접속: ssh -i mykey.pem ec2-user@<bastion_public_ip>
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

# 맵은 키 순서가 보장되지 않으므로 sort(keys(...))로 이름순 정렬해 항상 같은 순서의 목록을 출력한다.
output "public_subnet_ids" {
  value = [for k in sort(keys(local.public_subnets)) : aws_subnet.this[k].id]
}

output "private_subnet_ids" {
  value = [for k in sort(keys(local.private_subnets)) : aws_subnet.this[k].id]
}

# ---------- EC2 ----------
# { web1 = "10.0.10.10", web2 = "10.0.11.10", was1 = "10.0.20.10", was2 = "10.0.21.10" }
# bastion에서 각 서버로 SSH 접속할 때 쓰는 주소
output "server_private_ips" {
  value = { for k, v in aws_instance.server : k => v.private_ip }
}

# 보안 그룹 ID 모음
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

# ---------- 로드 밸런서 / 데이터 ----------
# 브라우저에서 http://<web_lb_dns_name> 으로 접속한다.
# NGINX·Flask 설치를 마치고 대상 그룹이 healthy가 되어야 정상 응답한다.
output "web_lb_dns_name" {
  description = "외부 ALB 주소 (브라우저 접속, 외부 DNS www CNAME 값)"
  value       = aws_lb.web.dns_name
}

output "was_lb_dns_name" {
  description = "내부 NLB 주소 (was.cloud.local)"
  value       = aws_lb.was.dns_name
}

# 실제 AWS 엔드포인트. 애플리케이션은 이 값 대신 internal_dns의 고정 이름을 사용한다.
output "rds_endpoint" {
  value = aws_db_instance.mysql.address
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

# Route 53 프라이빗 영역에 등록된 내부 도메인 이름 (VPC 안에서만 조회 가능)
output "internal_dns" {
  value = {
    db    = aws_route53_record.db.fqdn
    redis = aws_route53_record.redis.fqdn
    was   = aws_route53_record.was.fqdn
  }
}
