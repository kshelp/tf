variable "prefix" {
  type        = string
  description = "리소스 이름 접두사"
}

variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "address_space" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_prefix" {
  type    = string
  default = "10.0.10.0/24"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# 8.3.2 실습: add-env-variable 브랜치에서 추가하는 변수
variable "environment" {
  type        = string
  description = "Define infrastructure's environment"
  default     = "dev"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "The environment value must be dev, qa, or prod."
  }
}
