# 계층별 보안 그룹. 소스를 CIDR 대신 보안 그룹으로 지정해 계층 간 흐름만 허용한다.

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
  description = "HTTP from ALB, SSH from bastion"
  vpc_id      = aws_vpc.mynet.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
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
  description = "TCP 5000 from VPC (NLB), SSH from bastion"
  vpc_id      = aws_vpc.mynet.id

  ingress {
    description = "Flask from VPC (NLB health check, client IP preserved)"
    from_port   = 5000
    to_port     = 5000
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
