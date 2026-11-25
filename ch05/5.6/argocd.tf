# =============================================================================
# argocd.tf — Argo CD 설치와 GitOps 애플리케이션 (helm 프로바이더, versions.tf)
# -----------------------------------------------------------------------------
# 구성도 images/architecture-eks-argocd.png
#   Developer ──git push──▶ Git Repository (k8s manifests = gitops/)
#   ① Argo CD가 Git 저장소를 NAT 게이트웨이를 거쳐 pull 한다(변경 감시).
#   ② 변경 사항을 클러스터의 web / was 워크로드에 자동 동기화한다(양쪽 AZ 모두).
#
# 테라폼과 Argo CD의 역할 분담 (같은 리소스를 두 도구가 함께 관리하지 않는다)
#   테라폼  : 인프라(VPC, EKS, RDS, ElastiCache, LB, Route 53) + Argo CD 설치·Application + db-init(db_init.tf)
#   Argo CD : 앱(web·was Deployment / Service, NGINX ConfigMap) ← gitops/ 디렉터리
#
# 배치: Argo CD 파드는 모두 was-subnet-a(ap-northeast-2a)의 was 노드에 둔다(구성도의 was-a 서브넷 위치).
#       Git 저장소 접근은 노드의 기본 경로(프라이빗 서브넷 → NAT 게이트웨이 → IGW)를 그대로 쓰므로
#       보안 그룹·라우팅을 추가할 필요가 없다(was-sg egress 전체 허용).
# 접속: Argo CD 서버는 ClusterIP로만 두고 kubectl port-forward로 연다(outputs.tf의 argocd_* 출력 참고).
# =============================================================================

locals {
  argocd_namespace = "argocd"
}

# ---------- Argo CD 설치 (공식 Helm 차트 argo-cd) ----------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version # 차트 버전을 고정해 재현성을 확보한다
  namespace        = local.argocd_namespace
  create_namespace = true # helm uninstall 때 네임스페이스는 남는다(클러스터와 함께 삭제됨)

  # 모든 파드가 Ready가 될 때까지 기다린다(이미지 pull 포함 보통 2~3분).
  wait    = true
  timeout = 600

  values = [yamlencode({
    global = {
      # 구성도대로 was-a 서브넷(AZ a)의 was 노드에 배치
      #   tier=was                    : eks.tf 노드 그룹 레이블
      #   topology.kubernetes.io/zone : 노드가 속한 AZ (EKS가 자동으로 붙이는 표준 레이블)
      # t3.medium 노드당 파드 17개 → Argo CD 파드 5개 + was 파드 + 시스템 파드가 들어간다.
      nodeSelector = {
        tier                          = "was"
        "topology.kubernetes.io/zone" = var.azs["a"]
      }
    }

    # 실습에 필요 없는 구성 요소는 끈다(파드 수·메모리 절약).
    #   dex           : 외부 SSO(OIDC) 연동. admin 계정으로 로그인하므로 불필요
    #   notifications : Slack 등 알림
    dex           = { enabled = false }
    notifications = { enabled = false }

    configs = {
      cm = {
        # Git 저장소를 확인하는 주기(기본 120s). Webhook을 쓰지 않으므로 이 주기로 변경을 감지한다.
        "timeout.reconciliation" = "${var.argocd_reconciliation_seconds}s"
      }
    }
  })]

  # 노드가 있어야 파드가 뜨고, destroy 때 노드보다 먼저 삭제된다.
  depends_on = [
    aws_eks_node_group.this,
    aws_route_table_association.private, # 이미지 pull(quay.io, ghcr.io 등)에 NAT 경로 필요
  ]
}

# ---------- GitOps 애플리케이션 (Helm 차트 argocd-apps) ----------
# Application은 Argo CD의 CRD이므로 kubernetes_manifest로 만들면 CRD가 없는 첫 plan에서 실패한다.
# argocd-apps 차트로 만들면 Argo CD 설치 후 같은 apply 안에서 바로 생성할 수 있다.
resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = local.argocd_namespace

  values = [yamlencode({
    applications = {
      (var.gitops_app_name) = {
        namespace = local.argocd_namespace
        project   = "default"

        # ① Git 저장소의 gitops/ 디렉터리(kustomization.yaml)를 기준으로 삼는다.
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.gitops_repo_revision
          path           = var.gitops_repo_path

          # NodePort는 로드 밸런서 대상 그룹 포트(web_lb.tf, was_lb.tf)·보안 그룹(security.tf)과
          # 반드시 같아야 하므로 테라폼 변수 값으로 덮어쓴다. Git 매니페스트의 값과 달라도 이 값이 적용된다.
          kustomize = {
            patches = [
              for svc, port in { web = var.web_node_port, was = var.was_node_port } : {
                target               = { kind = "Service", name = svc }
                # JSON 패치(JSON은 YAML이기도 하므로 문자열 그대로 넘긴다)
                patch = jsonencode([{ op = "replace", path = "/spec/ports/0/nodePort", value = port }])
              }
            ]
          }
        }

        # ② 같은 클러스터의 default 네임스페이스에 배포 (db-init Job·Secret과 같은 곳)
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "default"
        }

        syncPolicy = {
          automated = {
            prune    = true # Git에서 지운 리소스는 클러스터에서도 지운다
            selfHeal = true # kubectl로 직접 고친 내용은 Git 상태로 되돌린다
          }
          retry = {
            limit   = 5
            backoff = { duration = "10s", factor = 2, maxDuration = "3m" }
          }
        }
        # finalizer를 두지 않는다. destroy 때 Application만 지워지고 앱 리소스는 클러스터와 함께 삭제된다.
        # (finalizer가 있으면 Argo CD가 먼저 지워질 경우 Application 삭제가 끝나지 않아 destroy가 멈출 수 있다)
      }
    }
  })]

  # 앱이 시작될 때 필요한 것들이 먼저 준비되어야 한다.
  depends_on = [
    helm_release.argocd,
    kubernetes_job_v1.db_init, # was: DB frodo·사용자·테이블
    aws_route53_record.redis,  # was: redis.cloud.local
    aws_route53_record.was,    # web(NGINX): was.cloud.local (이름을 못 찾으면 NGINX 기동 실패)
    aws_lb_listener.was,
  ]
}
