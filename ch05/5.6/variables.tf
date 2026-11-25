# =============================================================================
# variables.tf — 입력 변수 정의
# -----------------------------------------------------------------------------
# 값을 바꾸는 방법(우선순위 낮음 → 높음)
#   1) 아래 default 값
#   2) terraform.tfvars (자동으로 읽힘, terraform.tfvars.example 참고)
#   3) *.auto.tfvars
#   4) -var-file=xxx.tfvars, -var 'name=value' 명령행 인자
# default가 없는 변수(db_password)는 반드시 위 방법 중 하나로 값을 지정해야 한다.
# =============================================================================

# ---------- 환경 ----------
variable "env" {
  type        = string
  description = "배포 환경. 계정 안에서 고유해야 하는 리소스 이름의 접두사와 Environment 태그로 쓰인다"
  default     = "dev"

  # 입력값 검증: dev/stg/prod 이외의 값이면 plan 단계에서 바로 오류를 낸다.
  # 5.7의 권한 경계·State 버킷 경로가 이 세 환경 기준으로 만들어져 있기 때문이다.
  validation {
    condition     = contains(["dev", "stg", "prod"], var.env)
    error_message = "env는 dev, stg, prod 중 하나여야 합니다."
  }
}

variable "use_permissions_boundary" {
  type        = bool
  description = "true면 IAM 역할에 권한 경계 tf-boundary-<env>를 붙인다. 5.7의 배포 역할(tf-deployer-<env>)로 실행할 때 필수"
  default     = false # 관리자 자격 증명으로 직접 실행할 때는 경계 없이도 된다
}

# 모든 리소스를 만들 AWS 리전 (서울)
variable "region" {
  type    = string
  default = "ap-northeast-2"
}

# 서브넷 이름의 접미사(a, b)를 실제 가용 영역에 매핑한다.
# network.tf의 서브넷, NAT 게이트웨이, 프라이빗 라우팅 테이블이 이 맵을 for_each로 사용한다.
# 키 "b"가 ap-northeast-2c에 매핑되는 점에 주의(학습자료 구성도와 동일하게 2a·2c 사용).
variable "azs" {
  type        = map(string)
  description = "서브넷 접미사(a, b)와 가용 영역 매핑"
  default = {
    a = "ap-northeast-2a"
    b = "ap-northeast-2c"
  }
}

# VPC 전체 주소 범위. 서브넷 CIDR(network.tf)은 이 범위 안에 있어야 한다.
# security.tf의 was-sg 인바운드 규칙에서도 "VPC 내부에서 온 트래픽"을 표현하는 데 쓰인다.
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

# EC2 키 페어는 Terraform이 만들지 않는다. 콘솔이나 CLI로 미리 생성해 둔 이름을 넣는다.
variable "key_name" {
  type        = string
  description = "bastion과 EKS 노드 접속용 키 페어 이름 (콘솔에서 미리 생성)"
  default     = "mykey"
}

# 관리자(실습 PC) 접근 허용 범위. 기본값 0.0.0.0/0은 전 세계에서 SSH·EKS API 접근이 가능하므로
# 실제로는 terraform.tfvars에서 "내 공인 IP/32"로 좁히는 것이 좋다.
variable "admin_cidr" {
  type        = string
  description = "Bastion SSH와 EKS API(퍼블릭 엔드포인트) 접속을 허용할 CIDR. 실습 PC의 공인 IP/32로 좁히는 것을 권장"
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  type        = string
  description = "bastion 인스턴스 유형"
  default     = "t3.micro"
}

# ---------- EKS ----------
variable "cluster_name" {
  type        = string
  description = "클러스터 이름. 실제 이름은 <env>-<cluster_name> (예: dev-myeks)"
  default     = "myeks"
}

# EKS가 지원하는 버전만 지정할 수 있다. bastion.tf에서 같은 버전의 kubectl을 내려받는 데도 쓰인다.
variable "cluster_version" {
  type        = string
  description = "EKS 쿠버네티스 버전 (aws eks describe-cluster-versions로 확인)"
  default     = "1.37"
}

# VPC CNI는 노드 ENI의 보조 IP를 파드에 할당하므로, 인스턴스 유형에 따라 노드당 최대 파드 수가 정해진다.
# (t3.medium은 노드당 17개)
variable "node_instance_type" {
  type        = string
  description = "노드 유형. t3.micro는 노드당 파드 4개까지라 시스템 파드만으로 가득 차므로 t3.medium 이상"
  default     = "t3.medium"
}

# 노드 그룹 정의 맵. eks.tf의 시작 템플릿·노드 그룹이 이 맵을 for_each로 돌며 그룹마다 하나씩 만든다.
#   키(web, was) : 노드 그룹 이름 + 노드 레이블 tier 값 + 보안 그룹 선택 키(eks.tf local.node_tier_sg)
#   subnets      : 노드를 배치할 서브넷 이름 목록(network.tf local.subnets의 키)
#   size         : 노드 수(desired = min = max 로 고정)
variable "node_groups" {
  type = map(object({
    subnets = list(string)
    size    = number
  }))
  description = "노드 그룹 정의. 5.4의 web1·web2 → web, was1·was2 → was. 키는 노드 레이블 tier 값으로도 쓰인다"
  default = {
    web = { subnets = ["web-subnet-a", "web-subnet-b"], size = 2 }
    was = { subnets = ["was-subnet-a", "was-subnet-b"], size = 2 }
  }
}

# 서비스(NodePort) 포트: 로드 밸런서 대상 그룹이 노드의 이 포트로 보낸다.
# 쿠버네티스 NodePort 허용 범위(기본 30000~32767) 안의 값이어야 한다.
# 같은 값이 security.tf(인바운드 규칙), web_lb.tf/was_lb.tf(대상 그룹 포트)에 쓰이고,
# argocd.tf가 Argo CD Application의 kustomize 패치로 gitops/의 Service nodePort를 이 값으로 덮어쓴다.
variable "web_node_port" {
  type    = number
  default = 30080 # ALB(web-tg) → web 노드 :30080 → NGINX 파드 :80
}

variable "was_node_port" {
  type    = number
  default = 30500 # NLB(was-tg) → was 노드 :30500 → Flask 파드 :5000
}

# ---------- 애플리케이션 ----------
# WAS(Flask) 소스 저장소·커밋, 컨테이너 이미지 등 앱 설정은 gitops/ 매니페스트에서 관리한다(Argo CD).

# db_init.tf의 db-init Job이 이 암호로 MySQL 사용자 frodo를 만든다.
# sensitive = true 이면 plan/apply 출력에 값이 (sensitive value)로 가려진다(State에는 평문으로 저장됨).
variable "app_db_password" {
  type        = string
  description = "애플리케이션 DB 사용자 frodo의 암호. mywas2의 app.py에 하드코딩된 값과 같아야 한다"
  default     = "Frodo5020!!"
  sensitive   = true
}

# ---------- RDS / ElastiCache ----------
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

# RDS 마스터 사용자 이름. db-init Job도 이 사용자로 접속해 DB·사용자를 만든다.
variable "db_username" {
  type    = string
  default = "root"
}

# default가 없으므로 반드시 terraform.tfvars 등으로 지정해야 한다(없으면 plan 시 입력을 요구함).
variable "db_password" {
  type        = string
  description = "RDS 마스터 암호 (8자 이상). terraform.tfvars에 지정한다"
  sensitive   = true
}

# 다중 AZ는 대기 인스턴스 비용이 추가로 든다. 실습 비용을 줄이려면 false.
variable "db_multi_az" {
  type        = bool
  description = "true면 db-subnet-b에 대기(standby) 인스턴스를 둔다(구성도와 동일). 비용을 줄이려면 false"
  default     = true
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

# ---------- Argo CD (GitOps) ----------
# argocd.tf 참고. 구성도: images/architecture-eks-argocd.png

# https://artifacthub.io/packages/helm/argo/argo-cd 에서 버전 확인
variable "argocd_chart_version" {
  type        = string
  description = "argo-cd Helm 차트 버전 (10.11.7 = Argo CD v3.5.7)"
  default     = "10.11.7"
}

variable "argocd_apps_chart_version" {
  type        = string
  description = "argocd-apps Helm 차트 버전 (Application 생성용)"
  default     = "2.0.7"
}

variable "argocd_reconciliation_seconds" {
  type        = number
  description = "Argo CD가 Git 저장소 변경을 확인하는 주기(초)"
  default     = 120
}

# Argo CD가 web·was 앱을 가져오는 Git 저장소. gitops/ 디렉터리를 이 저장소에 push해 두어야 한다.
# 공개 저장소가 아니면 Argo CD에 저장소 자격 증명을 따로 등록해야 한다(README 참고).
variable "gitops_repo_url" {
  type        = string
  description = "앱 매니페스트(gitops/)가 있는 Git 저장소 HTTPS 주소. 예: https://github.com/<계정>/<저장소>.git"
  default     = "https://github.com/kshelp/tf.git"

  validation {
    condition     = startswith(var.gitops_repo_url, "https://")
    error_message = "gitops_repo_url은 https:// 로 시작하는 Git 저장소 주소여야 합니다."
  }
}

variable "gitops_repo_revision" {
  type        = string
  description = "동기화할 브랜치·태그·커밋"
  default     = "main"
}

variable "gitops_repo_path" {
  type        = string
  description = "저장소 안 매니페스트 디렉터리 (kustomization.yaml 위치)"
  default     = "ch05/5.6/gitops"
}

variable "gitops_app_name" {
  type        = string
  description = "Argo CD Application 이름"
  default     = "web-was"
}
