variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "azs" {
  type        = map(string)
  description = "서브넷 접미사(a, b)와 가용 영역 매핑"
  default = {
    a = "ap-northeast-2a"
    b = "ap-northeast-2c"
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "key_name" {
  type        = string
  description = "bastion과 EKS 노드 접속용 키 페어 이름 (콘솔에서 미리 생성)"
  default     = "mykey"
}

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
  type    = string
  default = "myeks"
}

variable "cluster_version" {
  type        = string
  description = "EKS 쿠버네티스 버전 (aws eks describe-cluster-versions로 확인)"
  default     = "1.37"
}

variable "node_instance_type" {
  type        = string
  description = "노드 유형. t3.micro는 노드당 파드 4개까지라 시스템 파드만으로 가득 차므로 t3.medium 이상"
  default     = "t3.medium"
}

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
variable "web_node_port" {
  type    = number
  default = 30080
}

variable "was_node_port" {
  type    = number
  default = 30500
}

# ---------- 애플리케이션 ----------
variable "was_app_repo" {
  type        = string
  description = "WAS(Flask) 소스 저장소 (학습자료 5.4.6)"
  default     = "https://github.com/frodo5020/mywas2.git"
}

variable "was_app_ref" {
  type        = string
  description = "WAS 소스 커밋. 재현성을 위해 고정한다"
  default     = "0ead62075b948048420eb861d741b389ad040ef9"
}

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

variable "db_username" {
  type    = string
  default = "root"
}

variable "db_password" {
  type        = string
  description = "RDS 마스터 암호 (8자 이상). terraform.tfvars에 지정한다"
  sensitive   = true
}

variable "db_multi_az" {
  type        = bool
  description = "true면 db-subnet-b에 대기(standby) 인스턴스를 둔다(구성도와 동일). 비용을 줄이려면 false"
  default     = true
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}
