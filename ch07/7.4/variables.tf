variable "prefix" {
  type        = string
  description = "리소스 이름 접두사. 팀원마다 다르게 지정해 이름 충돌을 피한다"
}

variable "region" {
  type        = string
  description = "AWS 리전"
  default     = "ap-northeast-2"
}

variable "environment" {
  type        = string
  description = "환경 이름"
  default     = "dev"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment는 dev, qa, prod 중 하나여야 한다."
  }
}

variable "address_space" {
  type        = string
  description = "VPC CIDR"
  default     = "10.0.0.0/16"
}

variable "subnet_prefix" {
  type        = string
  description = "서브넷 CIDR"
  default     = "10.0.10.0/24"
}

variable "instance_type" {
  type        = string
  description = "EC2 인스턴스 유형"
  default     = "t3.micro"
}

variable "message" {
  type        = string
  description = "웹 페이지에 표시할 메시지"
  default     = "Hello, Terraform collaboration!"
}
