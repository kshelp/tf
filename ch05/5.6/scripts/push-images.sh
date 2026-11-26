#!/usr/bin/env bash
# =============================================================================
# push-images.sh — app/<앱>/Dockerfile을 빌드해 ECR 리포지토리 <env>-<앱>에 push한다.
# -----------------------------------------------------------------------------
# 사용법 (ch05/5.6에서 실행)
#   scripts/push-images.sh            # web, was 모두
#   scripts/push-images.sh was        # was만
#
# 환경 변수
#   TF_VAR_env  : dev(기본) | stg | prod   → 리포지토리 이름 <env>-web, <env>-was
#   AWS_REGION  : ap-northeast-2(기본)
#
# 이미지 태그는 gitops/<앱>.yaml의 "image: <앱>:<태그>"에서 읽는다(Git이 기준).
# 리포지토리는 태그 변경 불가(IMMUTABLE)이므로 이미 있는 태그면 빌드하지 않고 건너뛴다.
# → 앱을 바꿨으면 gitops/<앱>.yaml의 태그를 올린 뒤 이 스크립트를 실행하고 git push 한다.
#
# terraform apply 때도 ecr.tf(terraform_data.image_push)가 이 스크립트를 실행한다.
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."   # ch05/5.6

ENV_NAME="${TF_VAR_env:-dev}"
REGION="${AWS_REGION:-ap-northeast-2}"
APPS=("$@")
[ ${#APPS[@]} -eq 0 ] && APPS=(web was)

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# ECR 로그인 (토큰 12시간 유효)
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY" >/dev/null

for app in "${APPS[@]}"; do
  repo="${ENV_NAME}-${app}"
  tag="$(sed -nE "s/^[[:space:]]*image:[[:space:]]*${app}:([^[:space:]#]+).*/\1/p" "gitops/${app}.yaml" | head -1)"
  if [ -z "$tag" ]; then
    echo "[$app] gitops/${app}.yaml에서 'image: ${app}:<태그>'를 찾지 못했습니다." >&2
    exit 1
  fi
  image="${REGISTRY}/${repo}:${tag}"

  if aws ecr describe-images --region "$REGION" --repository-name "$repo" \
       --image-ids imageTag="$tag" >/dev/null 2>&1; then
    echo "[$app] ${image} 이미 있음 → 건너뜀 (앱을 바꿨다면 gitops/${app}.yaml의 태그를 올리세요)"
    continue
  fi

  echo "[$app] 빌드·push: ${image}"
  # --platform linux/amd64 : EKS 노드(AL2023_x86_64)용. Apple Silicon Mac에서도 amd64로 빌드한다.
  # --provenance=false     : 증명(attestation) 없이 단일 이미지로 push (ECR에 태그 없는 항목이 생기지 않게)
  docker buildx build \
    --platform linux/amd64 \
    --provenance=false \
    --tag "$image" \
    --push \
    "app/${app}"
done
