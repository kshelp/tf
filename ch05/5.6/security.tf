# =============================================================================
# security.tf — 보안 그룹(방화벽 규칙)
# -----------------------------------------------------------------------------
# 계층별 보안 그룹. 소스를 CIDR 대신 보안 그룹으로 지정해 계층 간 흐름만 허용한다.
# 5.4와 같은 7개 보안 그룹을 쓰되, web-sg·was-sg는 EC2 대신 EKS 노드(시작 템플릿)에 붙는다.
#   - 노드에는 [EKS 클러스터 보안 그룹, web-sg 또는 was-sg]가 함께 붙는다(eks.tf).
#   - VPC CNI는 파드 IP를 노드 ENI에 할당하므로 파드도 노드의 보안 그룹을 따른다.
#     → was 파드에서 나가는 트래픽은 was-sg로 식별되어 mysql-sg·redis-sg 규칙에 그대로 맞는다.
#   - 로드 밸런서는 파드가 아니라 노드의 NodePort(web 30080, was 30500)로 보낸다.
#
# 허용되는 트래픽 흐름 요약
#   인터넷 ──80──▶ web-lb-sg(ALB) ──30080──▶ web-sg(web 노드)
#   web-sg ──5000──▶ was-lb-sg(NLB) ──30500──▶ was-sg(was 노드)   ※ NLB는 클라이언트 IP 보존 → VPC CIDR로 허용
#   was-sg ──3306──▶ mysql-sg(RDS)
#   was-sg ──6379──▶ redis-sg(ElastiCache)
#   관리자 ──22──▶ bastion-sg ──22/3306/6379/443──▶ 각 계층
#
# 보안 그룹은 상태 저장(stateful)이므로 허용된 요청의 응답 트래픽은 규칙 없이 자동 허용된다.
# 모든 그룹의 egress는 전체 허용(0.0.0.0/0, 모든 프로토콜)으로 두었다.
#   ※ Terraform은 AWS가 기본으로 만드는 "전체 허용 egress"를 지우므로, 필요하면 명시해야 한다.
# =============================================================================

locals {
  # EKS가 클러스터를 만들 때 자동으로 생성하는 "클러스터 보안 그룹" ID.
  # 컨트롤 플레인 ↔ 노드, 노드 ↔ 노드 통신을 허용하는 규칙이 미리 들어 있다.
  cluster_sg_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

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
  # ALB → web 노드(30080)로 나가는 트래픽과 상태 검사를 위해 필요
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "web-lb-sg" }
}

# ---------- web-sg : web 노드 그룹 ----------
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "web NodePort from ALB, SSH from bastion"
  vpc_id      = aws_vpc.mynet.id

  # ALB(web-lb-sg)에서 오는 트래픽만 web 서비스 NodePort(30080)로 허용.
  # ALB는 요청을 다시 만들어 보내므로(프록시) 출발지가 ALB의 IP = web-lb-sg 로 식별된다.
  ingress {
    description     = "web NodePort from ALB"
    from_port       = var.web_node_port
    to_port         = var.web_node_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web_lb.id]
  }
  # bastion을 거쳐서만 노드에 SSH 접속 가능
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  # NGINX 파드 → was NLB(5000), 이미지 다운로드(NAT 경유) 등
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

  # web 노드(그리고 그 위의 NGINX 파드)에서만 NLB 5000 포트로 접근 허용
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

# ---------- was-sg : was 노드 그룹 ----------
resource "aws_security_group" "was" {
  name        = "was-sg"
  description = "was NodePort from VPC (NLB), SSH from bastion"
  vpc_id      = aws_vpc.mynet.id

  # 인스턴스 대상 NLB는 기본적으로 "클라이언트 IP 보존"이 켜져 있어,
  # 노드에 도착하는 패킷의 출발지가 NLB가 아니라 원래 클라이언트(web 노드/파드 IP)다.
  # 또 NLB 상태 검사는 NLB 노드의 사설 IP에서 온다. 두 경우를 모두 허용하려고 VPC CIDR 전체를 연다.
  ingress {
    description = "was NodePort from VPC (NLB health check, client IP preserved)"
    from_port   = var.was_node_port
    to_port     = var.was_node_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  # Flask 파드 → RDS(3306), Redis(6379), pip·git(NAT 경유) 등
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

  # was 노드(=was 파드, db-init Job)와 bastion(접속 확인용)에서만 3306 허용
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

  # was 노드(=Flask 세션 저장소 접근)와 bastion(redis-cli 확인용)에서만 6379 허용
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

# ---------- EKS 클러스터 보안 그룹에 규칙 추가 ----------
# bastion → EKS API 프라이빗 엔드포인트(443). bastion에서 kubectl을 쓰기 위한 규칙
#
# 클러스터 보안 그룹은 EKS가 만든 것이라 aws_security_group 리소스로 관리할 수 없다.
# 그래서 규칙 하나만 별도 리소스(aws_vpc_security_group_ingress_rule)로 추가한다.
# VPC 안에서는 엔드포인트 이름이 프라이빗 IP(컨트롤 플레인 ENI)로 해석되므로 이 규칙이 필요하다.
resource "aws_vpc_security_group_ingress_rule" "cluster_from_bastion" {
  security_group_id            = local.cluster_sg_id
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "EKS API from bastion"
}
