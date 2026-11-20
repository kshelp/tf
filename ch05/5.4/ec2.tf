data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
  # 서버 정의: 이름 => { 서브넷, 고정 사설 IP, 보안 그룹 }
  servers = {
    web1 = { subnet = "web-subnet-a", ip = "10.0.10.10", sg = aws_security_group.web.id }
    web2 = { subnet = "web-subnet-b", ip = "10.0.11.10", sg = aws_security_group.web.id }
    was1 = { subnet = "was-subnet-a", ip = "10.0.20.10", sg = aws_security_group.was.id }
    was2 = { subnet = "was-subnet-b", ip = "10.0.21.10", sg = aws_security_group.was.id }
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.this["public-subnet-a"].id
  private_ip             = "10.0.0.10"
  vpc_security_group_ids = [aws_security_group.bastion.id]

  # RDS·ElastiCache 접속 확인용 MySQL(MariaDB)·Redis 클라이언트 설치
  user_data = <<-EOT
    #!/bin/bash
    dnf install -y mariadb105 redis6
  EOT

  tags = { Name = "bastion" }
}

resource "aws_instance" "server" {
  for_each = local.servers

  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.this[each.value.subnet].id
  private_ip             = each.value.ip
  vpc_security_group_ids = [each.value.sg]

  tags = { Name = each.key }

  # NAT 게이트웨이가 준비된 뒤 생성해야 부팅 시 패키지 저장소에 접근할 수 있다.
  depends_on = [aws_route_table_association.private]
}
