variable "instance_type" {
  type        = string
  description = "EC2 인스턴스 유형"
  default     = "t3.micro"
}

variable "instance_name" {
  type        = string
  description = "Name 태그 값"
  default     = "tf-module-ec2"
}

variable "subnet_id" {
  type        = string
  description = "인스턴스를 배치할 서브넷 ID. null이면 기본 VPC의 기본 서브넷"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "추가 태그"
  default     = {}
}
