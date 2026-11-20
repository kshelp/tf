# 5.4의 web1·web2, was1·was2 EC2를 EKS 관리형 노드 그룹 web, was로 바꾼다.
#   web 노드 그룹: web-subnet-a/b, 보안 그룹 web-sg, 레이블 tier=web  → NGINX 파드
#   was 노드 그룹: was-subnet-a/b, 보안 그룹 was-sg, 레이블 tier=was  → Flask 파드
# 노드 IP는 서브넷에서 자동 할당된다(5.4의 고정 IP .10은 노드 그룹에서 지정할 수 없다).

locals {
  # 컨트롤 플레인 ENI를 둘 서브넷 (노드 그룹이 쓰는 web/was 서브넷)
  cluster_subnets = ["web-subnet-a", "web-subnet-b", "was-subnet-a", "was-subnet-b"]

  # 노드 그룹별 계층 보안 그룹
  node_tier_sg = {
    web = aws_security_group.web.id
    was = aws_security_group.was.id
  }
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  access_config {
    authentication_mode                         = "API" # aws-auth ConfigMap 대신 액세스 항목(Access Entry) 사용
    bootstrap_cluster_creator_admin_permissions = true  # terraform을 실행한 IAM 사용자에게 관리자 권한
  }

  vpc_config {
    subnet_ids              = [for s in local.cluster_subnets : aws_subnet.this[s].id]
    endpoint_private_access = true # VPC 안(bastion, 노드)에서 접근
    endpoint_public_access  = true # 실습 PC의 terraform(kubernetes 프로바이더)·kubectl 접근
    public_access_cidrs     = [var.admin_cidr]
  }

  tags = { Name = var.cluster_name }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# Bastion IAM 역할에 클러스터 관리자 권한 부여
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.bastion.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.bastion.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}

# 시작 템플릿: 노드에 계층 보안 그룹(web-sg/was-sg)과 키 페어를 붙인다.
# 시작 템플릿에 보안 그룹을 지정하면 EKS가 클러스터 보안 그룹을 자동으로 붙이지 않으므로 함께 지정한다.
resource "aws_launch_template" "node" {
  for_each = var.node_groups

  name                   = "${each.key}-node"
  key_name               = var.key_name
  vpc_security_group_ids = [local.cluster_sg_id, local.node_tier_sg[each.key]]

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2 # 파드(컨테이너)에서 IMDS 접근
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${each.key}-node" }
  }
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [for s in each.value.subnets : aws_subnet.this[s].id]

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = [var.node_instance_type]
  capacity_type  = "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  scaling_config {
    desired_size = each.value.size
    min_size     = each.value.size
    max_size     = each.value.size
  }

  update_config {
    max_unavailable = 1
  }

  # 파드는 nodeSelector { tier = web | was }로 노드 그룹을 고른다.
  labels = { tier = each.key }

  depends_on = [
    aws_iam_role_policy_attachment.node,
    aws_route_table_association.private, # NAT 경로가 있어야 노드가 이미지를 받고 클러스터에 조인
  ]
}
