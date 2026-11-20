variable "prefix" {
  type        = string
  description = "클러스터 이름 접두사"
}

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes 버전"
  default     = "1.33"
}

variable "vpc_id" {
  type        = string
  description = "클러스터를 배치할 VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "노드와 컨트롤 플레인 ENI를 배치할 프라이빗 서브넷 ID"
}

variable "node_instance_types" {
  type        = list(string)
  description = "관리형 노드 그룹 인스턴스 유형"
  default     = ["t3.medium"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
