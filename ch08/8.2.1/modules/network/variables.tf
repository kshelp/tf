variable "env" {
  type        = string
  description = "환경 이름 (dev, prod)"
}

variable "cidr" {
  type        = string
  description = "VPC CIDR"
}

variable "azs" {
  type        = list(string)
  description = "서브넷을 만들 가용 영역 목록"
}
