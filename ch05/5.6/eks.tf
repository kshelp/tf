# =============================================================================
# eks.tf — EKS 클러스터, 액세스 항목, 시작 템플릿, 관리형 노드 그룹
# -----------------------------------------------------------------------------
# 5.4의 web1·web2, was1·was2 EC2를 EKS 관리형 노드 그룹 web, was로 바꾼다.
#   web 노드 그룹: web-subnet-a/b, 보안 그룹 web-sg, 레이블 tier=web  → NGINX 파드
#   was 노드 그룹: was-subnet-a/b, 보안 그룹 was-sg, 레이블 tier=was  → Flask 파드
# 노드 IP는 서브넷에서 자동 할당된다(5.4의 고정 IP .10은 노드 그룹에서 지정할 수 없다).
#
# 생성 순서(의존성)
#   IAM 역할(iam.tf) → 클러스터 → 클러스터 보안 그룹 생성됨 → 시작 템플릿 → 노드 그룹 → Argo CD·db-init(argocd.tf, db_init.tf)
#                              └→ bastion 액세스 항목 → bastion 인스턴스(bastion.tf)
# 클러스터 생성은 보통 10분 안팎, 노드 그룹은 3~5분 정도 걸린다.
# =============================================================================

locals {
  # 컨트롤 플레인 ENI를 둘 서브넷 (노드 그룹이 쓰는 web/was 서브넷)
  # EKS는 서로 다른 AZ의 서브넷이 최소 2개 필요하며, 여기에 API 서버와 통신할 ENI를 만든다.
  cluster_subnets = ["web-subnet-a", "web-subnet-b", "was-subnet-a", "was-subnet-b"]

  # 노드 그룹별 계층 보안 그룹 (var.node_groups의 키와 같아야 한다)
  node_tier_sg = {
    web = aws_security_group.web.id
    was = aws_security_group.was.id
  }
}

# ---------- EKS 클러스터 (컨트롤 플레인) ----------
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name # 예: dev-myeks
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn # EKS가 맡는 클러스터 IAM 역할

  # 클러스터 인증 방식
  access_config {
    authentication_mode                         = "API" # aws-auth ConfigMap 대신 액세스 항목(Access Entry) 사용
    bootstrap_cluster_creator_admin_permissions = true  # terraform을 실행한 IAM 사용자에게 관리자 권한
    # → 이 권한 덕분에 같은 apply 안에서 kubernetes 프로바이더가 바로 앱을 배포할 수 있다(versions.tf).
    # 관리형 노드 그룹의 노드 역할은 EKS가 액세스 항목(EC2_LINUX 유형)을 자동으로 만들어 준다.
  }

  vpc_config {
    subnet_ids = [for s in local.cluster_subnets : aws_subnet.this[s].id]

    # API 서버 엔드포인트를 퍼블릭·프라이빗 둘 다 연다.
    #   프라이빗: VPC 안에서는 엔드포인트 이름이 컨트롤 플레인 ENI의 사설 IP로 해석된다(노드 → API 트래픽이 VPC 밖으로 안 나감).
    #   퍼블릭  : 인터넷에서 접근 가능하되 public_access_cidrs로 출발지를 제한한다.
    endpoint_private_access = true # VPC 안(bastion, 노드)에서 접근
    endpoint_public_access  = true # 실습 PC의 terraform(kubernetes 프로바이더)·kubectl 접근
    public_access_cidrs     = [var.admin_cidr]
  }

  tags = { Name = local.cluster_name }

  # 역할에 정책이 붙기 전에 클러스터를 만들면 생성이 실패하거나,
  # destroy 때 정책이 먼저 떨어져 클러스터 리소스 정리가 안 될 수 있으므로 순서를 명시한다.
  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# ---------- 클러스터 접근 권한: Bastion ----------
# Bastion IAM 역할에 클러스터 관리자 권한 부여
# 액세스 항목(Access Entry) = "어떤 IAM 주체가 클러스터에 로그인할 수 있는가"
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.bastion.arn
  type          = "STANDARD" # 사람/도구용 일반 항목 (노드용은 EC2_LINUX 등)
}

# 액세스 정책 연결 = "로그인한 주체가 쿠버네티스 안에서 무엇을 할 수 있는가"
# AmazonEKSClusterAdminPolicy는 쿠버네티스 cluster-admin과 같은 전체 권한이다.
resource "aws_eks_access_policy_association" "bastion" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.bastion.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  # 적용 범위: 클러스터 전체 (type = "namespace"로 특정 네임스페이스만 줄 수도 있다)
  access_scope {
    type = "cluster"
  }

  # 액세스 항목이 있어야 정책을 연결할 수 있다.
  depends_on = [aws_eks_access_entry.bastion]
}

# ---------- 시작 템플릿 (노드 그룹마다 1개) ----------
# 시작 템플릿: 노드에 계층 보안 그룹(web-sg/was-sg)과 키 페어를 붙인다.
# 시작 템플릿에 보안 그룹을 지정하면 EKS가 클러스터 보안 그룹을 자동으로 붙이지 않으므로 함께 지정한다.
#
# AMI는 지정하지 않는다 → 노드 그룹의 ami_type(EKS 최적화 AL2023)을 쓰고 부트스트랩도 EKS가 자동 처리한다.
resource "aws_launch_template" "node" {
  for_each = var.node_groups # web, was

  name     = "${var.env}-${each.key}-node" # 예: dev-web-node
  key_name = var.key_name                  # bastion에서 ssh ec2-user@<노드 IP> 로 접속할 때 사용

  # [클러스터 보안 그룹(노드↔컨트롤 플레인, 노드↔노드 통신), 계층 보안 그룹(web-sg 또는 was-sg)]
  vpc_security_group_ids = [local.cluster_sg_id, local.node_tier_sg[each.key]]

  # 인스턴스 메타데이터 서비스(IMDS) 설정
  metadata_options {
    http_tokens = "required" # IMDSv2(토큰 방식)만 허용 → SSRF 등으로 자격 증명이 새는 것을 막는다
    # PUT 응답이 통과할 수 있는 네트워크 홉 수. 기본값 1이면 컨테이너(한 홉 더)에서 IMDS에 닿지 못한다.
    http_put_response_hop_limit = 2 # 파드(컨테이너)에서 IMDS 접근
  }

  # 이 템플릿으로 시작되는 EC2 인스턴스에 붙일 태그
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${each.key}-node", Environment = var.env } # 시작 템플릿 태그에는 default_tags가 붙지 않는다
  }
}

# ---------- 관리형 노드 그룹 (web, was) ----------
# EKS가 오토 스케일링 그룹(ASG)을 만들어 노드를 관리한다. 노드 교체·업그레이드 시 파드를 안전하게 옮겨 준다.
resource "aws_eks_node_group" "this" {
  for_each = var.node_groups # each.key = web | was, each.value = { subnets, size }

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn # 노드 EC2가 맡는 IAM 역할 (iam.tf)
  subnet_ids      = [for s in each.value.subnets : aws_subnet.this[s].id]

  ami_type       = "AL2023_x86_64_STANDARD" # EKS 최적화 Amazon Linux 2023 (클러스터 버전에 맞는 AMI 자동 선택)
  instance_types = [var.node_instance_type]
  capacity_type  = "ON_DEMAND" # SPOT으로 바꾸면 저렴하지만 회수될 수 있음

  # 위에서 만든 시작 템플릿 사용. latest_version을 쓰므로 템플릿이 바뀌면 노드 롤링 교체가 일어난다.
  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  # 노드 수를 size로 고정 (5.4의 web1·web2 / was1·was2처럼 계층당 2대)
  scaling_config {
    desired_size = each.value.size
    min_size     = each.value.size
    max_size     = each.value.size
  }

  # 업데이트(AMI·템플릿 변경 등) 시 한 번에 최대 1대씩만 교체 → 서비스 중단 최소화
  update_config {
    max_unavailable = 1
  }

  # 파드는 nodeSelector { tier = web | was }로 노드 그룹을 고른다.
  labels = { tier = each.key }

  depends_on = [
    aws_iam_role_policy_attachment.node, # 정책이 없으면 노드가 클러스터에 조인하지 못한다
    aws_route_table_association.private, # NAT 경로가 있어야 노드가 이미지를 받고 클러스터에 조인
  ]
}
