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

# VPC 전체 주소 범위(10.0.0.0 ~ 10.0.255.255). 서브넷 CIDR(network.tf)은 이 범위 안에 있어야 한다.
# security.tf의 was-sg 인바운드 규칙에서도 "VPC 내부에서 온 트래픽"을 표현하는 데 쓰인다.
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

# EC2 키 페어는 Terraform이 만들지 않는다. 콘솔이나 CLI로 미리 생성해 둔 이름을 넣는다.
# bastion과 web1·web2·was1·was2 모두 같은 키로 접속한다.
variable "key_name" {
  type        = string
  description = "EC2 접속용 키 페어 이름 (콘솔에서 미리 생성)"
  default     = "mykey"
}

# 관리자(실습 PC) 접근 허용 범위. 기본값 0.0.0.0/0은 전 세계에서 SSH 접근이 가능하므로
# 실제로는 terraform.tfvars에서 "내 공인 IP/32"로 좁히는 것이 좋다.
variable "admin_cidr" {
  type        = string
  description = "Bastion SSH 접속을 허용할 CIDR. 실습 PC의 공인 IP/32로 좁히는 것을 권장"
  default     = "0.0.0.0/0"
}

# bastion과 서버 4대(web1·web2·was1·was2)에 공통으로 쓰는 인스턴스 유형
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# ---------- RDS / ElastiCache ----------
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

# RDS 마스터 사용자 이름
variable "db_username" {
  type    = string
  default = "root"
}

# default가 없으므로 반드시 terraform.tfvars 등으로 지정해야 한다(없으면 plan 시 입력을 요구함).
# sensitive = true 이면 plan/apply 출력에 값이 (sensitive value)로 가려진다(State에는 평문으로 저장됨).
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
