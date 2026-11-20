data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.this["public-subnet-a"].id
  private_ip             = "10.0.0.10"
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  # RDS·ElastiCache 접속 확인용 MySQL(MariaDB)·Redis 클라이언트 설치 (5.4와 동일)
  # + 클러스터 버전에 맞는 kubectl 설치와 kubeconfig 생성
  user_data = <<-EOT
    #!/bin/bash
    dnf install -y mariadb105 redis6
    curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable-${var.cluster_version}.txt)/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl
    sudo -u ec2-user aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}
  EOT

  tags = { Name = "bastion" }

  depends_on = [aws_eks_access_policy_association.bastion]
}
