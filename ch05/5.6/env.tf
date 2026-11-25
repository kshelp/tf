# =============================================================================
# env.tf — 환경(dev / stg / prod) 공통 값
# -----------------------------------------------------------------------------
# 환경(dev, stg, prod) 구분
#   - 계정 안에서 고유해야 하는 이름(IAM 역할, EKS, RDS, ElastiCache, LB/TG, 시작 템플릿)에 <env>- 접두사를 붙인다.
#   - 모든 리소스에 Environment = <env> 태그를 붙인다(versions.tf default_tags).
#   - VPC·보안 그룹·Route 53 프라이빗 영역은 환경마다 별도 VPC에 생기므로 이름이 같아도 된다.
#
# 한 AWS 계정에 세 환경을 동시에 올려도 이름이 충돌하지 않도록 하는 것이 목적이다.
# 예) env = "dev"  → EKS 클러스터 dev-myeks, RDS dev-mysql, ALB dev-web-lb
#     env = "prod" → EKS 클러스터 prod-myeks, RDS prod-mysql, ALB prod-web-lb
# =============================================================================

# 현재 terraform을 실행하는 자격 증명의 계정 ID·ARN을 조회하는 데이터 소스.
# 아래 권한 경계 정책 ARN을 만들 때 계정 ID를 하드코딩하지 않기 위해 사용한다.
data "aws_caller_identity" "current" {}

locals {
  # 실제 EKS 클러스터 이름. 예: dev-myeks
  # iam.tf의 역할 이름(<cluster_name>-cluster-role 등)에도 이 값이 쓰여 환경별로 구분된다.
  cluster_name = "${var.env}-${var.cluster_name}"

  # 5.7에서 만든 권한 경계. 배포 역할은 이 경계를 붙인 IAM 역할만 만들 수 있다.
  #
  # 권한 경계(Permissions Boundary): IAM 역할이 가질 수 있는 "최대 권한"의 상한선.
  # 5.7의 배포 역할(tf-deployer-<env>)은 "경계가 붙은 역할만 생성 가능"하도록 제한되어 있으므로,
  # 그 역할로 실행할 때는 use_permissions_boundary = true 로 경계를 붙여야 iam:CreateRole이 허용된다.
  # false(기본값)이면 null이 되어 iam.tf의 permissions_boundary 인자가 생략된 것과 같다.
  permissions_boundary_arn = var.use_permissions_boundary ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/tf-boundary-${var.env}" : null
}
