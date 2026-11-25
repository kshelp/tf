# =============================================================================
# security.tf — 보안 그룹(방화벽 규칙) 7개
# -----------------------------------------------------------------------------
# 계층별 보안 그룹. 소스를 CIDR 대신 보안 그룹으로 지정해 계층 간 흐름만 허용한다.
#   예) mysql-sg의 소스 = was-sg → "was-sg가 붙은 인스턴스"에서 온 트래픽만 허용.
#       서버 IP가 바뀌거나 서버가 늘어도 규칙을 고칠 필요가 없다.
#
# 허용되는 트래픽 흐름 요약
#   인터넷 ──80──▶ web-lb-sg(ALB) ──80──▶ web-sg(web1, web2: NGINX)
#   web-sg ──5000──▶ was-lb-sg(NLB) ──5000──▶ was-sg(was1, was2: Flask)  ※ NLB는 클라이언트 IP 보존 → VPC CIDR로 허용
#   was-sg ──3306──▶ mysql-sg(RDS)
#   was-sg ──6379──▶ redis-sg(ElastiCache)
#   관리자 ──22──▶ bastion-sg ──22/3306/6379──▶ 각 계층
#
# 보안 그룹은 상태 저장(stateful)이므로 허용된 요청의 응답 트래픽은 규칙 없이 자동 허용된다.
# 모든 그룹의 egress는 전체 허용(0.0.0.0/0, 모든 프로토콜)으로 두었다.
#   ※ Terraform은 AWS가 기본으로 만드는 "전체 허용 egress"를 지우므로, 필요하면 명시해야 한다.
# =============================================================================

# ---------- bastion-sg : 관리자 PC → bastion SSH ----------
resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "SSH from admin"
  vpc_id      = aws_vpc.mynet.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr] # 관리자 공인 IP/32 로 좁히는 것을 권장 (variables.tf)
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 = 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "bastion-sg" }
}

# ---------- web-lb-sg : 인터넷 → 외부 ALB(HTTP 80) ----------
resource "aws_security_group" "web_lb" {
  name        = "web-lb-sg"
  description = "HTTP from internet to ALB"
  vpc_id      = aws_vpc.mynet.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 누구나 웹 서비스에 접속 가능
  }
  # ALB → web 서버(80)로 나가는 트래픽과 상태 검사를 위해 필요
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "web-lb-sg" }
}

# ---------- web-sg : web1, web2 (NGINX) ----------
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "HTTP from ALB, SSH from bastion"
  vpc_id      = aws_vpc.mynet.id

  # ALB(web-lb-sg)에서 오는 HTTP만 허용.
  # ALB는 요청을 다시 만들어 보내므로(프록시) 출발지가 ALB의 IP = web-lb-sg 로 식별된다.
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_lb.id]
  }
  # bastion을 거쳐서만 SSH 접속 가능 (NGINX 설치·설정 작업용)
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  # NGINX → was NLB(5000), dnf 패키지 설치(NAT 경유) 등
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "web-sg" }
}

# ---------- was-lb-sg : web 계층 → 내부 NLB(TCP 5000) ----------
# NLB에도 보안 그룹을 붙일 수 있다(생성 시에만 지정 가능, was_lb.tf).
resource "aws_security_group" "was_lb" {
  name        = "was-lb-sg"
  description = "TCP 5000 from web tier to internal NLB"
  vpc_id      = aws_vpc.mynet.id

  # web 서버에서만 NLB 5000 포트로 접근 허용
  ingress {
    description     = "Flask from web"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "was-lb-sg" }
}

# ---------- was-sg : was1, was2 (Flask) ----------
resource "aws_security_group" "was" {
  name        = "was-sg"
  description = "TCP 5000 from VPC (NLB), SSH from bastion"
  vpc_id      = aws_vpc.mynet.id

  # 인스턴스 대상 NLB는 기본적으로 "클라이언트 IP 보존"이 켜져 있어,
  # was 서버에 도착하는 패킷의 출발지가 NLB가 아니라 원래 클라이언트(web 서버 IP)다.
  # 또 NLB 상태 검사는 NLB 노드의 사설 IP에서 온다. 두 경우를 모두 허용하려고 VPC CIDR 전체를 연다.
  ingress {
    description = "Flask from VPC (NLB health check, client IP preserved)"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  # bastion을 거쳐서만 SSH 접속 가능 (Flask 설치·실행 작업용)
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  # Flask → RDS(3306), Redis(6379), pip·git(NAT 경유) 등
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "was-sg" }
}

# ---------- mysql-sg : RDS MySQL ----------
resource "aws_security_group" "mysql" {
  name        = "mysql-sg"
  description = "MySQL from WAS and bastion"
  vpc_id      = aws_vpc.mynet.id

  # was 서버(애플리케이션)와 bastion(DB·사용자 생성, 접속 확인)에서만 3306 허용
  ingress {
    description     = "MySQL"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.was.id, aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "mysql-sg" }
}

# ---------- redis-sg : ElastiCache Redis ----------
resource "aws_security_group" "redis" {
  name        = "redis-sg"
  description = "Redis from WAS and bastion"
  vpc_id      = aws_vpc.mynet.id

  # was 서버(Flask 세션 저장소 접근)와 bastion(redis-cli 확인용)에서만 6379 허용
  ingress {
    description     = "Redis"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.was.id, aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "redis-sg" }
}
