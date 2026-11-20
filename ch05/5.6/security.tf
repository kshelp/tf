# 계층별 보안 그룹. 소스를 CIDR 대신 보안 그룹으로 지정해 계층 간 흐름만 허용한다.
# 5.4와 같은 7개 보안 그룹을 쓰되, web-sg·was-sg는 EC2 대신 EKS 노드(시작 템플릿)에 붙는다.
#   - 노드에는 [EKS 클러스터 보안 그룹, web-sg 또는 was-sg]가 함께 붙는다(eks.tf).
#   - VPC CNI는 파드 IP를 노드 ENI에 할당하므로 파드도 노드의 보안 그룹을 따른다.
#     → was 파드에서 나가는 트래픽은 was-sg로 식별되어 mysql-sg·redis-sg 규칙에 그대로 맞는다.
#   - 로드 밸런서는 파드가 아니라 노드의 NodePort(web 30080, was 30500)로 보낸다.

locals {
  cluster_sg_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "SSH from admin"
  vpc_id      = aws_vpc.mynet.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "bastion-sg" }
}

resource "aws_security_group" "web_lb" {
  name        = "web-lb-sg"
  description = "HTTP from internet to ALB"
  vpc_id      = aws_vpc.mynet.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "web-lb-sg" }
}

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "web NodePort from ALB, SSH from bastion"
  vpc_id      = aws_vpc.mynet.id

  ingress {
    description     = "web NodePort from ALB"
    from_port       = var.web_node_port
    to_port         = var.web_node_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web_lb.id]
  }
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "web-sg" }
}

resource "aws_security_group" "was_lb" {
  name        = "was-lb-sg"
  description = "TCP 5000 from web tier to internal NLB"
  vpc_id      = aws_vpc.mynet.id

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

resource "aws_security_group" "was" {
  name        = "was-sg"
  description = "was NodePort from VPC (NLB), SSH from bastion"
  vpc_id      = aws_vpc.mynet.id

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
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "was-sg" }
}

resource "aws_security_group" "mysql" {
  name        = "mysql-sg"
  description = "MySQL from WAS and bastion"
  vpc_id      = aws_vpc.mynet.id

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

resource "aws_security_group" "redis" {
  name        = "redis-sg"
  description = "Redis from WAS and bastion"
  vpc_id      = aws_vpc.mynet.id

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

# bastion → EKS API 프라이빗 엔드포인트(443). bastion에서 kubectl을 쓰기 위한 규칙
resource "aws_vpc_security_group_ingress_rule" "cluster_from_bastion" {
  security_group_id            = local.cluster_sg_id
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "EKS API from bastion"
}
