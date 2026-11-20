variable "project" {
  description = "GCP project id"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster (regional cluster)"
  type        = string
  default     = "asia-northeast3" # 서울
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "my-gke-cluster"
}

variable "subnet_cidr" {
  description = "CIDR for the subnetwork"
  type        = string
  default     = "10.10.0.0/20"
}

variable "machine_type" {
  description = "Node machine type"
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  description = "Node count per zone for the node pool"
  type        = number
  default     = 2
}

variable "node_locations" {
  description = "노드를 배치할 영역 목록. null이면 리전의 모든 영역(보통 3개)에 배치"
  type        = list(string)
  default     = null
}

variable "master_version" {
  description = "GKE control plane version (empty for default/latest)"
  type        = string
  default     = ""
}
