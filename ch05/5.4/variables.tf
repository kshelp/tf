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
  description = "EC2 접속용 키 페어 이름 (콘솔에서 미리 생성)"
  default     = "mykey"
}

variable "admin_cidr" {
  type        = string
  description = "Bastion SSH 접속을 허용할 CIDR. 실습 PC의 공인 IP/32로 좁히는 것을 권장"
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
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
