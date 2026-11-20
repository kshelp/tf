# Route 53 프라이빗 호스팅 영역: cloud.local
# 레코드는 각 절의 파일에서 등록한다.
#   db.cloud.local    → rds.tf          (5.4.5 2. Route 53에 레코드 등록)
#   redis.cloud.local → elasticache.tf  (5.4.6 2. Route 53에 레코드 등록)
#   was.cloud.local   → was_lb.tf       (5.4.7 7. Route 53에 레코드 등록)

resource "aws_route53_zone" "private" {
  name = "cloud.local"
  vpc {
    vpc_id = aws_vpc.mynet.id
  }
}
