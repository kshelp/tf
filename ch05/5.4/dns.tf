# =============================================================================
# dns.tf — Route 53 프라이빗 호스팅 영역
# -----------------------------------------------------------------------------
# Route 53 프라이빗 호스팅 영역: cloud.local
# 레코드는 각 절의 파일에서 등록한다.
#   db.cloud.local    → rds.tf          (5.4.5 2. Route 53에 레코드 등록)
#   redis.cloud.local → elasticache.tf  (5.4.6 2. Route 53에 레코드 등록)
#   was.cloud.local   → was_lb.tf       (5.4.7 7. Route 53에 레코드 등록)
#
# 왜 내부 도메인을 쓰는가?
#   RDS·ElastiCache·NLB의 엔드포인트는 재생성될 때마다 바뀌는 긴 AWS 주소다.
#   애플리케이션(app.py, NGINX 설정)은 고정된 이름(db/redis/was.cloud.local)만 알고,
#   실제 주소는 CNAME 레코드가 가리키게 해 인프라가 바뀌어도 앱 설정을 고치지 않게 한다.
#
# 프라이빗 영역은 연결된 VPC 안에서만 조회된다(인터넷에서는 보이지 않음).
# VPC의 enable_dns_support / enable_dns_hostnames(network.tf)가 켜져 있어야 동작한다.
# =============================================================================

resource "aws_route53_zone" "private" {
  name = "cloud.local"

  # vpc 블록이 있으면 프라이빗 호스팅 영역이 된다(없으면 퍼블릭 영역).
  vpc {
    vpc_id = aws_vpc.mynet.id
  }
}
