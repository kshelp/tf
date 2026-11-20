variable "region" {
  type        = string
  description = "AWS 리전"
  default     = "ap-northeast-2"
}

variable "environment" {
  type        = string
  description = "환경 이름 (dev, stg, prod)"
  default     = "dev"
  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment는 dev, stg, prod 중 하나여야 한다."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR 블록"
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr는 올바른 CIDR 형식이어야 한다."
  }
}

variable "azs" {
  type        = list(string)
  description = "서브넷을 만들 가용 영역 (a, c)"
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}
