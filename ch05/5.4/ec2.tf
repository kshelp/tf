# =============================================================================
# ec2.tf — EC2 인스턴스: bastion + web1·web2·was1·was2
# -----------------------------------------------------------------------------
# Terraform은 "서버(빈 OS)"까지만 만든다. 애플리케이션 설치는 학습자료대로 서버에 접속해 직접 한다.
#   web1·web2 : NGINX 설치·프록시 설정 (5.4.8 1~2)
#   was1·was2 : Flask 앱 설치·서비스 등록 (5.4.7 1~5)
# 접속 경로: 관리자 PC ──ssh──▶ bastion(공인 IP) ──ssh──▶ 각 서버(사설 IP 10.0.x.10)
#   예) ssh -A -i mykey.pem ec2-user@<bastion_public_ip>  →  ssh ec2-user@10.0.10.10
# =============================================================================

# 최신 Amazon Linux 2023 AMI(x86_64)를 조회한다.
# most_recent = true 이므로 apply 시점에 새 AMI가 나왔다면 인스턴스 교체가 계획될 수 있다.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"] # AWS 공식 이미지만 대상으로
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"] # 최소 버전(al2023-ami-minimal-*)은 제외되는 패턴
  }
}

locals {
  # 서버 정의: 이름 => { 서브넷, 고정 사설 IP, 보안 그룹 }
  # 서버마다 리소스 블록을 복사하지 않고, 이 맵을 for_each로 돌려 4대를 한 번에 만든다.
  # 고정 IP는 각 서브넷의 .10 → 구성도의 "10" 표시와 같다.
  servers = {
    web1 = { subnet = "web-subnet-a", ip = "10.0.10.10", sg = aws_security_group.web.id }
    web2 = { subnet = "web-subnet-b", ip = "10.0.11.10", sg = aws_security_group.web.id }
    was1 = { subnet = "was-subnet-a", ip = "10.0.20.10", sg = aws_security_group.was.id }
    was2 = { subnet = "was-subnet-b", ip = "10.0.21.10", sg = aws_security_group.was.id }
  }
}

# ---------- bastion (점프 서버) ----------
# 퍼블릭 서브넷에 둔 유일한 SSH 진입점. 프라이빗 서브넷의 서버·DB는 여기를 거쳐서만 접근한다.
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  key_name      = var.key_name # 미리 만들어 둔 키 페어 (ssh -i mykey.pem ec2-user@<공인 IP>)

  subnet_id  = aws_subnet.this["public-subnet-a"].id # 공인 IP 자동 할당 서브넷(network.tf)
  private_ip = "10.0.0.10"                           # 고정 사설 IP

  vpc_security_group_ids = [aws_security_group.bastion.id]

  # RDS·ElastiCache 접속 확인용 MySQL(MariaDB)·Redis 클라이언트 설치
  # user_data는 인스턴스 "최초 부팅" 때 root로 한 번 실행된다.
  #   mariadb105 → mysql 명령 (mysql -h db.cloud.local -u root -p)
  #   redis6     → redis-cli 명령 (redis-cli --tls -h redis.cloud.local)
  user_data = <<-EOT
    #!/bin/bash
    dnf install -y mariadb105 redis6
  EOT

  tags = { Name = "bastion" }
}

# ---------- web1, web2, was1, was2 ----------
resource "aws_instance" "server" {
  for_each = local.servers # each.key = 서버 이름, each.value = { subnet, ip, sg }

  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id  = aws_subnet.this[each.value.subnet].id # 프라이빗 서브넷 → 공인 IP 없음
  private_ip = each.value.ip                         # 서브넷 범위 안의 고정 IP

  vpc_security_group_ids = [each.value.sg] # web 서버는 web-sg, was 서버는 was-sg

  tags = { Name = each.key } # 콘솔에 web1, web2, was1, was2로 표시

  # NAT 게이트웨이가 준비된 뒤 생성해야 부팅 시 패키지 저장소에 접근할 수 있다.
  # (서브넷이 프라이빗 라우팅 테이블에 연결되어야 NAT 경로가 생기므로 연결 리소스에 의존)
  depends_on = [aws_route_table_association.private]
}
