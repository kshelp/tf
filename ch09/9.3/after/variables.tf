variable "region" {
  type        = string
  description = "AWS 리전"
  default     = "ap-northeast-2"
}

variable "environment" {
  type        = string
  description = "환경 이름"
  default     = "dev"
}
