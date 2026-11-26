# =============================================================================
# ecr.tf — Amazon ECR: web·was 컨테이너 이미지 저장소
# -----------------------------------------------------------------------------
# 구성도 images/architecture-eks-argocd.png
#   Developer ──docker push──▶ Amazon ECR (<env>-web, <env>-was)
#   ③ web·was 노드(kubelet)가 NAT 게이트웨이를 거쳐 ECR에서 이미지를 pull 한다.
#      인증은 노드 IAM 역할의 AmazonEC2ContainerRegistryReadOnly(iam.tf)로 하므로 imagePullSecrets가 필요 없다.
#
# 이미지 주소가 Git에 들어가지 않게 하는 방법
#   ECR 주소(<계정 ID>.dkr.ecr.<리전>.amazonaws.com/<env>-web)는 계정·환경마다 다르다.
#   gitops/ 매니페스트에는 "image: web:<태그>"처럼 이름과 태그만 적고,
#   Argo CD Application이 kustomize images로 이름을 ECR 주소로 바꾼다(argocd.tf). 태그는 Git 값이 그대로 쓰인다.
#
# 이미지 빌드·push
#   처음 apply 때 terraform_data.image_push가 scripts/push-images.sh를 실행해 이미지를 올린다(실습 PC에 Docker 필요).
#   이후 앱을 바꿀 때는 gitops/<앱>.yaml의 태그를 올리고 scripts/push-images.sh 실행 → git push (README "앱 변경").
# =============================================================================

locals {
  ecr_apps = toset(["web", "was"])

  # 이미지 태그의 기준은 gitops/<앱>.yaml이다. 예: "image: was:1.0.0" → "1.0.0"
  app_image_tags = {
    for app in local.ecr_apps :
    app => regex("image:\\s*${app}:([^\\s#]+)", file("${path.module}/gitops/${app}.yaml"))[0]
  }
}

# ---------- 리포지토리: <env>-web, <env>-was ----------
resource "aws_ecr_repository" "this" {
  for_each = local.ecr_apps
  name     = "${var.env}-${each.key}"

  # 같은 태그로 다른 이미지를 덮어쓰지 못하게 한다.
  # GitOps는 매니페스트의 태그가 바뀌어야 배포가 일어나므로, 태그 = 이미지 내용이 항상 같아야 한다.
  image_tag_mutability = "IMMUTABLE"

  # push할 때마다 기본 취약점 스캔 (결과: 콘솔 또는 aws ecr describe-image-scan-findings)
  image_scanning_configuration {
    scan_on_push = true
  }

  # 이미지가 남아 있어도 terraform destroy로 리포지토리를 지운다(실습용).
  force_delete = true
}

# ---------- 수명 주기 정책: 오래된 이미지 자동 삭제 (저장 비용 절약) ----------
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "태그 없는 이미지는 1일 뒤 삭제"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 1 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "태그 있는 이미지는 최근 10개만 보관 (롤백용)"
        selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
        action       = { type = "expire" }
      },
    ]
  })
}

# ---------- 첫 이미지 빌드·push ----------
# Argo CD가 web·was를 배포하기 전에 ECR에 이미지가 있어야 한다(없으면 파드가 ImagePullBackOff).
# 태그나 app/<앱>/ 내용이 바뀌면 다시 실행된다. 스크립트는 이미 있는 태그면 건너뛴다(IMMUTABLE).
#
# for_each로 앱마다 나누지 않고 하나의 리소스에서 web·was를 차례로 처리한다.
# 나누면 테라폼이 두 스크립트를 동시에 실행하고, 두 docker login이 macOS 키체인(osxkeychain)에
# 같은 레지스트리 자격 증명을 동시에 저장하려다 "The specified item already exists in the keychain"으로 실패한다.
resource "terraform_data" "image_push" {
  triggers_replace = {
    for app in local.ecr_apps : app => {
      repository = aws_ecr_repository.this[app].repository_url
      tag        = local.app_image_tags[app]
      source = sha1(join("", [
        for f in sort(fileset("${path.module}/app/${app}", "**")) : filesha1("${path.module}/app/${app}/${f}")
      ]))
    }
  }

  provisioner "local-exec" {
    command     = "scripts/push-images.sh ${join(" ", sort(tolist(local.ecr_apps)))}"
    working_dir = path.module
    environment = {
      TF_VAR_env = var.env
      AWS_REGION = var.region
    }
  }
}
