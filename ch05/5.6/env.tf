# =============================================================================
# env.tf — 환경(dev / stg / prod) 공통 값
# -----------------------------------------------------------------------------
# 환경(dev, stg, prod) 구분
#   - 계정 안에서 고유해야 하는 이름(IAM 역할, EKS, RDS, ElastiCache, LB/TG, 시작 템플릿)에 <env>- 접두사를 붙인다.
#   - 모든 리소스에 Environment = <env> 태그를 붙인다(versions.tf default_tags).
#   - VPC·보안 그룹·Route 53 프라이빗 영역은 환경마다 별도 VPC에 생기므로 이름이 같아도 된다.
#   - State는 워크스페이스로 환경마다 나눈다(terraform workspace select -or-create <env>).
#
# 한 AWS 계정에 세 환경을 동시에 올려도 이름이 충돌하지 않도록 하는 것이 목적이다.
# 예) env = "dev"  → EKS 클러스터 dev-myeks, RDS dev-mysql, ALB dev-web-lb
#     env = "prod" → EKS 클러스터 prod-myeks, RDS prod-mysql, ALB prod-web-lb
# =============================================================================

locals {
  # 실제 EKS 클러스터 이름. 예: dev-myeks
  # iam.tf의 역할 이름(<cluster_name>-cluster-role 등)에도 이 값이 쓰여 환경별로 구분된다.
  cluster_name = "${var.env}-${var.cluster_name}"
}
