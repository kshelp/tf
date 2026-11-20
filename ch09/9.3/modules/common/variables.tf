variable "prefix" {
  type        = string
  description = "리소스 이름 접두사 (예: dev)"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR 블록"
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  type        = map(string)
  description = "가용 영역 => 프라이빗 서브넷 CIDR"
  default = {
    "ap-northeast-2a" = "10.0.1.0/24"
    "ap-northeast-2c" = "10.0.2.0/24"
  }
}

variable "tags" {
  type        = map(string)
  description = "모든 리소스에 붙일 공통 태그"
  default     = {}
}
