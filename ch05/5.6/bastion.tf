# =============================================================================
# bastion.tf — 관리용 점프 서버(Bastion Host)
# -----------------------------------------------------------------------------
# 퍼블릭 서브넷에 둔 유일한 SSH 진입점. 프라이빗 서브넷의 리소스는 여기를 거쳐서만 접근한다.
#   - SSH        : 관리자 PC → bastion → (SSH) → web/was 노드
#   - DB 확인    : bastion → mysql -h db.cloud.local / redis-cli --tls -h redis.cloud.local
#   - 클러스터   : bastion → kubectl → EKS API 프라이빗 엔드포인트(443)
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

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  key_name      = var.key_name # 미리 만들어 둔 키 페어 (ssh -i mykey.pem ec2-user@<공인 IP>)

  subnet_id  = aws_subnet.this["public-subnet-a"].id # 공인 IP 자동 할당 서브넷(network.tf)
  private_ip = "10.0.0.10"                           # 5.4와 같은 고정 사설 IP

  vpc_security_group_ids = [aws_security_group.bastion.id]

  # IAM 역할(iam.tf)을 인스턴스에 연결 → 인스턴스 안의 aws CLI가 별도 키 없이 이 역할 권한을 쓴다.
  # 이 역할은 EKS 액세스 항목(eks.tf)으로 클러스터 관리자 권한을 받는다.
  iam_instance_profile = aws_iam_instance_profile.bastion.name

  # RDS·ElastiCache 접속 확인용 MySQL(MariaDB)·Redis 클라이언트 설치 (5.4와 동일)
  # + 클러스터 버전에 맞는 kubectl 설치와 kubeconfig 생성
  #
  # user_data는 인스턴스 "최초 부팅" 때 root로 한 번 실행된다.
  #   - ${...} 는 Terraform이 렌더링 시점에 값으로 치환한다(var.cluster_version, 클러스터 이름 등).
  #   - $(...) 는 셸 명령 치환으로 인스턴스에서 실행된다(stable-<버전>.txt에서 최신 패치 버전 조회).
  #   - kubeconfig는 ec2-user 홈(~/.kube/config)에 만들어야 하므로 sudo -u ec2-user 로 실행한다.
  # 주의: user_data 내용이 바뀌면 인스턴스가 교체(재생성)될 수 있다.
  user_data = <<-EOT
    #!/bin/bash
    dnf install -y mariadb105 redis6
    curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable-${var.cluster_version}.txt)/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl
    sudo -u ec2-user aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}
  EOT

  tags = { Name = "bastion" }

  # 부팅 직후 kubectl을 바로 쓸 수 있도록, 클러스터 접근 권한이 먼저 부여된 뒤 인스턴스를 만든다.
  # (속성 참조만으로는 이 순서가 보장되지 않으므로 명시적 의존성을 준다)
  depends_on = [aws_eks_access_policy_association.bastion]
}
