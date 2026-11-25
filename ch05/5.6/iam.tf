# =============================================================================
# iam.tf — IAM 역할 (EKS 컨트롤 플레인, 워커 노드, Bastion)
# -----------------------------------------------------------------------------
# IAM 역할 = "누가(신뢰 정책) 이 역할을 맡을 수 있고, 맡으면 무엇을(권한 정책) 할 수 있는가"
#   - assume_role_policy : 신뢰 정책. 이 역할을 맡을 수 있는 주체(Principal)를 지정한다.
#   - policy_attachment  : 역할에 AWS 관리형 정책을 붙여 실제 권한을 준다.
#
# 모든 역할 이름에 local.cluster_name(<env>-myeks)을 붙여 환경별로 구분한다(env.tf).
# permissions_boundary는 5.7의 배포 역할로 실행할 때만 값이 들어가고, 그 외에는 null(미지정)이다.
# =============================================================================

# ---------- EKS 컨트롤 플레인 ----------
# EKS 서비스가 이 역할을 맡아 사용자 계정의 ENI·로드 밸런서 등을 관리한다.
resource "aws_iam_role" "cluster" {
  name                 = "${local.cluster_name}-cluster-role"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" } # EKS 서비스만 맡을 수 있음
      # sts:TagSession은 EKS Auto Mode 등 최신 기능에서 세션 태그 전달에 필요하다.
      Action = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

# 클러스터 운영에 필요한 기본 권한(EC2 ENI·보안 그룹 조회/생성, ELB 관리 등)
resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------- 워커 노드 (web, was 노드 그룹 공용) ----------
# 노드(EC2 인스턴스)가 맡는 역할. 노드 위의 kubelet, VPC CNI(aws-node) 등이 이 권한을 쓴다.
resource "aws_iam_role" "node" {
  name                 = "${local.cluster_name}-node-role"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" } # EC2 인스턴스가 맡는 역할
      Action    = "sts:AssumeRole"
    }]
  })
}

# 노드에 필요한 AWS 관리형 정책 3개를 for_each로 한꺼번에 연결한다.
#   AmazonEKSWorkerNodePolicy          : 노드가 클러스터에 조인하고 EC2 정보를 조회
#   AmazonEKS_CNI_Policy               : VPC CNI가 ENI를 붙이고 파드에 VPC IP를 할당
#   AmazonEC2ContainerRegistryReadOnly : ECR에서 이미지(시스템 애드온 등)를 내려받기
resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# ---------- Bastion: kubectl로 클러스터를 관리 ----------
# bastion 인스턴스가 맡는 역할. 쿠버네티스 안에서의 권한은 IAM이 아니라
# EKS 액세스 항목(eks.tf의 aws_eks_access_entry / access_policy_association)으로 따로 준다.
resource "aws_iam_role" "bastion" {
  name                 = "${local.cluster_name}-bastion-role"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# 인라인 정책: aws eks update-kubeconfig가 클러스터 엔드포인트·CA를 조회하는 데 필요한 최소 권한.
# (kubectl 요청 자체의 토큰은 eks get-token이 STS로 서명해 만들므로 별도 IAM 권한이 필요 없다)
resource "aws_iam_role_policy" "bastion_eks" {
  name = "eks-describe"
  role = aws_iam_role.bastion.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# 인스턴스 프로파일: EC2에 IAM 역할을 연결하기 위한 "그릇".
# EC2는 역할을 직접 받지 않고 인스턴스 프로파일을 통해 받는다(bastion.tf의 iam_instance_profile).
resource "aws_iam_instance_profile" "bastion" {
  name = "${local.cluster_name}-bastion-profile"
  role = aws_iam_role.bastion.name
}
