# =============================================================================
# versions.tf — Terraform 실행 환경, 프로바이더, 백엔드(State 저장소) 설정
# -----------------------------------------------------------------------------
# 이 파일은 다음을 정의한다.
# (web·was 앱은 테라폼이 아니라 Argo CD가 Git의 gitops/ 매니페스트로 배포한다 → argocd.tf)
#   1) terraform 블록 : Terraform CLI 최소 버전, 사용할 프로바이더와 버전 범위, State 백엔드
#   2) provider "aws"        : AWS 리소스(VPC, EKS, RDS, ElastiCache, LB 등)를 만드는 프로바이더
#   3) provider "kubernetes" : EKS 클러스터 안에 DB 초기화 Job·Secret을 만드는 프로바이더 (db_init.tf)
#   4) provider "helm"       : EKS 클러스터에 Argo CD(Helm 차트)를 설치하는 프로바이더 (argocd.tf)
# =============================================================================

terraform {
  # S3 백엔드의 네이티브 잠금(use_lockfile)은 Terraform 1.10부터 지원된다.
  # 이전에는 잠금용 DynamoDB 테이블이 따로 필요했지만, 1.10 이상에서는 S3 객체(.tflock)로 잠근다.
  required_version = ">= 1.10" # S3 backend use_lockfile

  required_providers {
    # AWS 프로바이더 6.x 사용. "~> 6.0"은 6.0 이상 7.0 미만을 뜻한다(메이저 업그레이드 방지).
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # 쿠버네티스 프로바이더 3.x 사용. db_init.tf의 *_v1 리소스(kubernetes_job_v1 등)를 제공한다.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    # Helm 프로바이더 3.x. argocd.tf의 helm_release(Argo CD, Application)를 제공한다.
    # 3.x부터 provider 블록의 kubernetes·exec가 블록이 아니라 객체 속성(= { ... })이다.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }

  # 환경별 State: terraform init -backend-config=env/<env>.s3.tfbackend -backend-config="bucket=<5.7의 state_bucket 출력>"
  # 버킷·IAM 권한은 ch05/5.7에서 만든다.
  #
  # 백엔드 블록을 비워 두는 "부분 구성(partial configuration)" 방식이다.
  #   - key, region, encrypt, use_lockfile → env/<env>.s3.tfbackend 파일에서 읽는다.
  #   - bucket                             → init 명령의 -backend-config 인자로 넘긴다.
  # 이렇게 하면 같은 코드로 dev/stg/prod State를 서로 다른 key(경로)에 분리해 저장할 수 있다.
  # 환경을 바꿀 때는 terraform init -reconfigure 로 백엔드를 다시 초기화한다.
  backend "s3" {}
}

# -----------------------------------------------------------------------------
# AWS 프로바이더
# -----------------------------------------------------------------------------
provider "aws" {
  # 모든 AWS 리소스를 만들 리전(기본값 ap-northeast-2, 서울). variables.tf 참고
  region = var.region

  # default_tags: 이 프로바이더로 만드는 "태그를 지원하는 모든 리소스"에 자동으로 붙는 공통 태그.
  # 각 리소스의 tags와 병합되며, 같은 키가 있으면 리소스 쪽 값이 우선한다.
  # 주의: 시작 템플릿의 tag_specifications(인스턴스에 전파되는 태그)에는 적용되지 않는다(eks.tf 참고).
  default_tags {
    tags = {
      Project     = "ch05-3tier-eks" # 비용·리소스 검색 시 프로젝트 구분용
      ManagedBy   = "terraform"      # 콘솔에서 손으로 고치지 말라는 표시
      Environment = var.env          # 5.7의 IAM 정책이 이 태그로 다른 환경 리소스 변경을 막는다
    }
  }
}

# -----------------------------------------------------------------------------
# 쿠버네티스 프로바이더
# -----------------------------------------------------------------------------
# DB 초기화 Job(db_init.tf) 생성용. 클러스터가 만들어진 뒤 aws eks get-token으로 인증한다.
# terraform을 실행하는 IAM 주체는 클러스터 생성자로서 관리자 권한을 받는다(eks.tf).
#
# 프로바이더 설정이 aws_eks_cluster.this 속성을 참조하므로, 처음 apply 할 때는
# 클러스터가 먼저 만들어진 뒤에 쿠버네티스·Helm 리소스가 생성된다.
provider "kubernetes" {
  # EKS API 서버 주소 (https://xxxx.gr7.ap-northeast-2.eks.amazonaws.com 형태)
  host = aws_eks_cluster.this.endpoint

  # API 서버 TLS 인증서를 검증할 CA 인증서. EKS는 base64로 인코딩해 주므로 디코딩해서 넘긴다.
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

  # exec 플러그인 인증: 요청할 때마다 aws CLI로 단기 토큰(약 15분 유효)을 새로 받는다.
  # 토큰을 State에 저장하지 않고, 오래 걸리는 apply 중에도 토큰 만료 문제가 생기지 않는다.
  # → 실행 PC에 aws CLI가 설치되어 있고 같은 자격 증명(프로파일)을 써야 한다.
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name, "--region", var.region]
  }
}

# -----------------------------------------------------------------------------
# Helm 프로바이더
# -----------------------------------------------------------------------------
# Argo CD 설치용(argocd.tf). 쿠버네티스 프로바이더와 같은 방식(exec + aws eks get-token)으로 인증한다.
provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name, "--region", var.region]
    }
  }
}
