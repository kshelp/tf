# =============================================================================
# rds.tf — Amazon RDS for MySQL + 내부 DNS 레코드(db.cloud.local)
# -----------------------------------------------------------------------------
# 5.4.5 RDS 구성하기
#   엔진: MySQL / 식별자: mysql / 마스터 사용자: root
#   VPC: mynet / 보안 그룹: default, mysql-sg
#   db-subnet-a 기본, db-subnet-b 대기 (db_multi_az = true일 때)
#
# 애플리케이션용 DB(frodo)와 사용자(frodo)는 여기서 만들지 않는다.
# → 학습자료 5.4.5 3단계대로 bastion에서 mysql 클라이언트로 접속해 SQL로 생성한다.
# RDS 생성은 단일 AZ 약 5~10분, 다중 AZ는 그보다 더 걸린다.
# =============================================================================

# ---------- 1. RDS 생성하기 ----------
# DB 서브넷 그룹: RDS가 사용할 수 있는 서브넷 목록. 서로 다른 AZ의 서브넷이 최소 2개 필요하다.
resource "aws_db_subnet_group" "mysql" {
  name       = "mysql"
  subnet_ids = [aws_subnet.this["db-subnet-a"].id, aws_subnet.this["db-subnet-b"].id]
  tags       = { Name = "mysql" }
}

resource "aws_db_instance" "mysql" {
  identifier        = "mysql" # 계정·리전 안에서 고유한 인스턴스 이름 (엔드포인트 주소에 포함됨)
  engine            = "mysql"
  engine_version    = "8.4" # 메이저.마이너만 지정 → 해당 계열의 기본 패치 버전 사용
  instance_class    = var.db_instance_class
  allocated_storage = 20 # GiB
  storage_type      = "gp3"

  # 마스터 사용자. 암호는 sensitive 변수지만 State 파일에는 평문으로 저장되므로 State 보관에 주의한다.
  username = var.db_username
  password = var.db_password

  db_subnet_group_name = aws_db_subnet_group.mysql.name
  # default 보안 그룹은 콘솔 실습과 동일하게 함께 붙인다. 실제 접근 허용은 mysql-sg가 담당한다.
  vpc_security_group_ids = [aws_vpc.mynet.default_security_group_id, aws_security_group.mysql.id]
  publicly_accessible    = false # 공인 IP 미부여 → VPC 안에서만 접근
  multi_az               = var.db_multi_az

  # 다중 AZ면 AWS가 기본/대기 AZ를 정하므로 null(미지정).
  # 단일 AZ면 db-subnet-a가 있는 AZ(ap-northeast-2a)에 고정한다.
  availability_zone = var.db_multi_az ? null : var.azs["a"]

  backup_retention_period = 1     # 자동 백업 1일 보관 (0이면 자동 백업 비활성화)
  skip_final_snapshot     = true  # 실습용: destroy 시 최종 스냅샷을 만들지 않음
  deletion_protection     = false # 실습용: true면 terraform destroy가 실패한다
  apply_immediately       = true  # 설정 변경을 다음 유지 관리 기간까지 미루지 않고 즉시 적용

  tags = { Name = "mysql" }
}

# ---------- 2. Route 53에 레코드 등록: db.cloud.local ----------
# db.cloud.local → mysql.xxxxxxxx.ap-northeast-2.rds.amazonaws.com
# 다중 AZ 장애 조치 시 RDS 엔드포인트가 가리키는 IP가 바뀌므로, A 레코드가 아니라 CNAME으로 엔드포인트 "이름"을 가리킨다.
resource "aws_route53_record" "db" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db.cloud.local"
  type    = "CNAME"
  ttl     = 60                              # 초. 짧게 두어 엔드포인트가 바뀌어도 빨리 반영되게 한다
  records = [aws_db_instance.mysql.address] # address = 포트 없는 호스트 이름 (endpoint는 :3306 포함)
}
