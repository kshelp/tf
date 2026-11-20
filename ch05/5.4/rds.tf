# 5.4.5 RDS 구성하기
#   엔진: MySQL / 식별자: mysql / 마스터 사용자: root
#   VPC: mynet / 보안 그룹: default, mysql-sg
#   db-subnet-a 기본, db-subnet-b 대기 (db_multi_az = true일 때)

# ---------- 1. RDS 생성하기 ----------
resource "aws_db_subnet_group" "mysql" {
  name       = "mysql"
  subnet_ids = [aws_subnet.this["db-subnet-a"].id, aws_subnet.this["db-subnet-b"].id]
  tags       = { Name = "mysql" }
}

resource "aws_db_instance" "mysql" {
  identifier        = "mysql"
  engine            = "mysql"
  engine_version    = "8.4"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"

  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_vpc.mynet.default_security_group_id, aws_security_group.mysql.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az
  availability_zone      = var.db_multi_az ? null : var.azs["a"]

  backup_retention_period = 1
  skip_final_snapshot     = true # 실습용: destroy 시 최종 스냅샷을 만들지 않음
  deletion_protection     = false
  apply_immediately       = true

  tags = { Name = "mysql" }
}

# ---------- 2. Route 53에 레코드 등록: db.cloud.local ----------
resource "aws_route53_record" "db" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db.cloud.local"
  type    = "CNAME"
  ttl     = 60
  records = [aws_db_instance.mysql.address]
}
