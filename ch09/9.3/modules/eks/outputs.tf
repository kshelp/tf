output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API 엔드포인트"
  value       = module.eks.cluster_endpoint
}
