# =============================================================================
# outputs.tf — 출력 값
# -----------------------------------------------------------------------------
# apply가 끝나면 화면에 출력되고, 이후에도 다음 명령으로 다시 볼 수 있다.
#   terraform output                    # 전체
#   terraform output -raw web_url       # 따옴표 없이 값만 (스크립트에서 사용)
#   terraform output -json              # JSON 형식
# =============================================================================

# ---------- 네트워크 ----------
output "vpc_id" {
  value = aws_vpc.mynet.id
}

# 관리자 PC에서 접속: ssh -i mykey.pem ec2-user@<bastion_public_ip>
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

# 맵은 키 순서가 보장되지 않으므로 sort(keys(...))로 이름순 정렬해 항상 같은 순서의 목록을 출력한다.
output "public_subnet_ids" {
  value = [for k in sort(keys(local.public_subnets)) : aws_subnet.this[k].id]
}

output "private_subnet_ids" {
  value = [for k in sort(keys(local.private_subnets)) : aws_subnet.this[k].id]
}

# 보안 그룹 ID 모음 (cluster = EKS가 자동 생성한 클러스터 보안 그룹)
output "security_group_ids" {
  value = {
    bastion = aws_security_group.bastion.id
    web_lb  = aws_security_group.web_lb.id
    web     = aws_security_group.web.id
    was_lb  = aws_security_group.was_lb.id
    was     = aws_security_group.was.id
    mysql   = aws_security_group.mysql.id
    redis   = aws_security_group.redis.id
    cluster = local.cluster_sg_id
  }
}

# ---------- EKS ----------
output "cluster_name" {
  value = aws_eks_cluster.this.name
}

# 출력된 명령을 그대로 실행하면 ~/.kube/config에 클러스터 접속 정보가 추가된다.
# 이후 kubectl get nodes, kubectl get pods -o wide 등으로 확인한다.
output "kubeconfig_command" {
  description = "실습 PC에서 kubectl을 설정하는 명령"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}"
}

# { web = "eks-web-xxxx", was = "eks-was-xxxx" } 형태
output "node_groups" {
  description = "노드 그룹별 오토 스케일링 그룹 (5.4의 web1·web2, was1·was2 대신)"
  value       = { for k, v in aws_eks_node_group.this : k => v.resources[0].autoscaling_groups[0].name }
}

# ---------- 로드 밸런서 / 데이터 ----------
# 브라우저로 열어 서비스 동작을 확인한다. 대상 그룹이 healthy가 될 때까지 몇 분 걸릴 수 있다.
output "web_url" {
  description = "브라우저 접속 주소"
  value       = "http://${aws_lb.web.dns_name}"
}

output "web_lb_dns_name" {
  description = "외부 ALB 주소 (브라우저 접속, 외부 DNS www CNAME 값)"
  value       = aws_lb.web.dns_name
}

output "was_lb_dns_name" {
  description = "내부 NLB 주소 (was.cloud.local)"
  value       = aws_lb.was.dns_name
}

# 실제 AWS 엔드포인트. 애플리케이션은 이 값 대신 internal_dns의 고정 이름을 사용한다.
output "rds_endpoint" {
  value = aws_db_instance.mysql.address
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

# Route 53 프라이빗 영역에 등록된 내부 도메인 이름 (VPC 안에서만 조회 가능)
output "internal_dns" {
  value = {
    db    = aws_route53_record.db.fqdn
    redis = aws_route53_record.redis.fqdn
    was   = aws_route53_record.was.fqdn
  }
}

# ---------- Argo CD ----------
# 실습 PC(또는 bastion)에서 kubeconfig_command를 먼저 실행한 뒤 사용한다.
output "argocd_port_forward_command" {
  description = "Argo CD UI 접속: 실행 후 https://localhost:8080 (자체 서명 인증서 경고는 무시), 사용자 admin"
  value       = "kubectl -n ${local.argocd_namespace} port-forward svc/argocd-server 8080:443"
}

output "argocd_admin_password_command" {
  description = "Argo CD 초기 admin 암호 확인"
  value       = "kubectl -n ${local.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
}

output "gitops_app" {
  description = "Argo CD Application (web·was 앱을 Git에서 동기화)"
  value = {
    name     = var.gitops_app_name
    repo     = var.gitops_repo_url
    revision = var.gitops_repo_revision
    path     = var.gitops_repo_path
    status   = "kubectl -n ${local.argocd_namespace} get application ${var.gitops_app_name}"
  }
}

# ---------- ECR ----------
output "ecr_repository_urls" {
  description = "web·was 이미지 리포지토리 (태그는 gitops/<앱>.yaml 기준)"
  value       = { for app, repo in aws_ecr_repository.this : app => repo.repository_url }
}

output "app_images" {
  description = "Argo CD가 배포하는 web·was 이미지"
  value       = { for app, repo in aws_ecr_repository.this : app => "${repo.repository_url}:${local.app_image_tags[app]}" }
}
