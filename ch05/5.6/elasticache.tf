# =============================================================================
# elasticache.tf — Amazon ElastiCache (Redis OSS) + 내부 DNS 레코드(redis.cloud.local)
# -----------------------------------------------------------------------------
# 5.4.6 Amazon ElastiCache 설정하기
#   엔진: Redis OSS / 배포 옵션: 노드 기반 캐시 / 생성 방법: 클러스터 캐시 / 클러스터 모드: 비활성화됨
#   이름: redis / 다중 AZ: 사용 안 함 / 자동 장애 조치: 사용 안 함 / 복제본 개수: 0
#   서브넷 그룹: redis (VPC mynet) / 보안 그룹: default, redis-sg / 자동 백업: 해제
#
# 용도: Flask 애플리케이션(was 파드)의 세션 저장소(Flask-Session).
# =============================================================================

# ---------- 1. ElastiCache 생성 ----------
# 캐시 서브넷 그룹: 캐시 노드를 배치할 수 있는 서브넷 목록 (RDS와 같은 db 서브넷 사용)
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.env}-redis"
  subnet_ids = [aws_subnet.this["db-subnet-a"].id, aws_subnet.this["db-subnet-b"].id]
}

# 복제 그룹(replication group) 리소스를 쓰는 이유:
#   전송 중 암호화(TLS)·저장 시 암호화 같은 옵션은 aws_elasticache_cluster가 아니라
#   aws_elasticache_replication_group에서 지원된다. 콘솔에서 만드는 Redis OSS 캐시도 내부적으로 복제 그룹이다.
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.env}-redis" # 계정·리전 안에서 고유한 이름
  description          = "session store"
  engine               = "redis"
  engine_version       = "7.1"
  parameter_group_name = "default.redis7" # 클러스터 모드 비활성화 (클러스터 모드는 default.redis7.cluster.on)
  node_type            = var.redis_node_type
  port                 = 6379

  # 노드 구성: 기본(primary) 1개만, 복제본 없음
  num_cache_clusters          = 1              # 기본 노드 1개 + 복제본 0개
  preferred_cache_cluster_azs = [var.azs["a"]] # 노드를 ap-northeast-2a(db-subnet-a)에 배치
  multi_az_enabled            = false          # 복제본이 없으므로 다중 AZ·자동 장애 조치는 켤 수 없다
  automatic_failover_enabled  = false

  subnet_group_name = aws_elasticache_subnet_group.redis.name
  # default 보안 그룹은 콘솔 실습과 동일하게 함께 붙인다. 실제 접근 허용은 redis-sg가 담당한다.
  security_group_ids = [aws_vpc.mynet.default_security_group_id, aws_security_group.redis.id]

  snapshot_retention_limit = 0 # 자동 백업 해제

  # 암호화 설정
  transit_encryption_enabled = true # 콘솔 기본값: 전송 중 암호화 → redis-cli --tls 로 접속
  at_rest_encryption_enabled = true # 디스크(스냅샷 포함) 암호화
  apply_immediately          = true # 변경을 유지 관리 기간까지 미루지 않고 즉시 적용

  tags = { Name = "redis" }
}

# ---------- 2. Route 53에 레코드 등록: redis.cloud.local ----------
# 값은 기본 엔드포인트에서 포트 번호를 뺀 주소
# 앱(app.py)은 redis.cloud.local:6379 에 TLS로 접속한다.
resource "aws_route53_record" "redis" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "redis.cloud.local"
  type    = "CNAME"
  ttl     = 60
  # 클러스터 모드 비활성화 복제 그룹의 기본(쓰기) 엔드포인트. 장애 조치 시에도 이 이름은 유지된다.
  records = [aws_elasticache_replication_group.redis.primary_endpoint_address]
}
