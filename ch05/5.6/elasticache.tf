# 5.4.6 Amazon ElastiCache 설정하기
#   엔진: Redis OSS / 배포 옵션: 노드 기반 캐시 / 생성 방법: 클러스터 캐시 / 클러스터 모드: 비활성화됨
#   이름: redis / 다중 AZ: 사용 안 함 / 자동 장애 조치: 사용 안 함 / 복제본 개수: 0
#   서브넷 그룹: redis (VPC mynet) / 보안 그룹: default, redis-sg / 자동 백업: 해제

# ---------- 1. ElastiCache 생성 ----------
resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis"
  subnet_ids = [aws_subnet.this["db-subnet-a"].id, aws_subnet.this["db-subnet-b"].id]
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "redis"
  description          = "session store"
  engine               = "redis"
  engine_version       = "7.1"
  parameter_group_name = "default.redis7" # 클러스터 모드 비활성화
  node_type            = var.redis_node_type
  port                 = 6379

  num_cache_clusters          = 1 # 기본 노드 1개 + 복제본 0개
  preferred_cache_cluster_azs = [var.azs["a"]]
  multi_az_enabled            = false
  automatic_failover_enabled  = false

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_vpc.mynet.default_security_group_id, aws_security_group.redis.id]

  snapshot_retention_limit = 0 # 자동 백업 해제

  transit_encryption_enabled = true # 콘솔 기본값: 전송 중 암호화 → redis-cli --tls 로 접속
  at_rest_encryption_enabled = true
  apply_immediately          = true

  tags = { Name = "redis" }
}

# ---------- 2. Route 53에 레코드 등록: redis.cloud.local ----------
# 값은 기본 엔드포인트에서 포트 번호를 뺀 주소
resource "aws_route53_record" "redis" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "redis.cloud.local"
  type    = "CNAME"
  ttl     = 60
  records = [aws_elasticache_replication_group.redis.primary_endpoint_address]
}
