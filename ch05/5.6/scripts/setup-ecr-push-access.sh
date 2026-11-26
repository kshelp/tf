#!/usr/bin/env bash
# =============================================================================
# setup-ecr-push-access.sh — 앱 개발자에게 ECR 이미지 push 권한을 준다 (IAM 그룹 + 고객 관리형 정책)
# -----------------------------------------------------------------------------
# 개발자 PC에서 scripts/push-images.sh를 실행하는 데 필요한 권한만 준다.
#
#   API                                   쓰는 곳                              리소스
#   sts:GetCallerIdentity                 계정 ID 확인                         (권한 불필요, 항상 허용)
#   ecr:GetAuthorizationToken             docker login 토큰                    * (리소스 지정 불가)
#   ecr:DescribeImages                    같은 태그가 이미 있는지 확인         <env>-<앱>
#   ecr:BatchCheckLayerAvailability       레이어가 이미 있는지 확인            <env>-<앱>
#   ecr:InitiateLayerUpload / UploadLayerPart / CompleteLayerUpload
#                                         레이어 업로드                        <env>-<앱>
#   ecr:PutImage                          매니페스트(태그) 등록                <env>-<앱>
#   ecr:BatchGetImage / GetDownloadUrlForLayer
#                                         buildx가 push 중 기존 매니페스트·레이어 조회   <env>-<앱>
#
# 리포지토리 생성·삭제, 정책·수명 주기 변경, 태그 변경 불가 설정(IMMUTABLE) 해제는 주지 않는다(테라폼 ecr.tf 담당).
#
# 만드는 것 (다시 실행해도 안전하다: 있으면 갱신)
#   IAM 고객 관리형 정책 <그룹>-ecr-push   (기본 app-developers-ecr-push)
#   IAM 그룹 <그룹>                         (기본 app-developers), 위 정책 연결
#   -u로 지정한 IAM 사용자를 그룹에 추가 (사용자는 미리 있어야 한다)
#
# 사용법 (IAM 관리 권한이 있는 자격 증명으로 실행)
#   scripts/setup-ecr-push-access.sh -u dev1 -u dev2                  # dev·stg·prod의 web·was
#   scripts/setup-ecr-push-access.sh -e dev -a was -u dev1            # dev-was에만
#   scripts/setup-ecr-push-access.sh -n                               # 정책 JSON만 출력 (AWS 변경 없음)
#
# 옵션
#   -e <env,...>   환경 (기본 dev,stg,prod). gitops/를 모든 환경이 함께 보므로 보통 전부 준다(README "앱 변경")
#   -a <앱,...>    앱 (기본 web,was)
#   -g <그룹>      IAM 그룹 이름 (기본 app-developers)
#   -u <사용자>    그룹에 추가할 IAM 사용자 (여러 번 지정 가능)
#   -n             dry-run: 정책 JSON만 출력
#
# 환경 변수
#   AWS_REGION     ap-northeast-2(기본)
# =============================================================================
set -euo pipefail

ENVS="dev,stg,prod"
APPS="web,was"
GROUP="app-developers"
USERS=()
DRY_RUN=false
REGION="${AWS_REGION:-ap-northeast-2}"

usage() { sed -n '2,/^# ====/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while getopts "e:a:g:u:nh" opt; do
  case "$opt" in
    e) ENVS="$OPTARG" ;;
    a) APPS="$OPTARG" ;;
    g) GROUP="$OPTARG" ;;
    u) USERS+=("$OPTARG") ;;
    n) DRY_RUN=true ;;
    *) usage ;;
  esac
done

POLICY_NAME="${GROUP}-ecr-push"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

# ---------- 정책 문서: 리포지토리 ARN 목록 <env>-<앱> ----------
repo_arns=""
IFS=',' read -ra env_list <<< "$ENVS"
IFS=',' read -ra app_list <<< "$APPS"
for e in "${env_list[@]}"; do
  for a in "${app_list[@]}"; do
    repo_arns+="${repo_arns:+,}
        \"arn:aws:ecr:${REGION}:${ACCOUNT_ID}:repository/${e}-${a}\""
  done
done

POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EcrLogin",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "PushAppImages",
      "Effect": "Allow",
      "Action": [
        "ecr:DescribeImages",
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": [${repo_arns}
      ]
    }
  ]
}
EOF
)

if $DRY_RUN; then
  echo "$POLICY_DOC"
  exit 0
fi

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

# ---------- 정책: 없으면 만들고, 있으면 새 기본 버전으로 갱신 ----------
if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  # 정책 버전은 최대 5개 → 꽉 찼으면 기본이 아닌 가장 오래된 버전을 지운다
  versions=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
    --query 'sort_by(Versions[?IsDefaultVersion==`false`], &CreateDate)[].VersionId' --output text)
  count=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'length(Versions)' --output text)
  if [ "$count" -ge 5 ]; then
    oldest=$(echo "$versions" | awk '{print $1}')
    aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$oldest"
  fi
  aws iam create-policy-version --policy-arn "$POLICY_ARN" \
    --policy-document "$POLICY_DOC" --set-as-default >/dev/null
  echo "정책 갱신: ${POLICY_NAME}"
else
  aws iam create-policy --policy-name "$POLICY_NAME" \
    --description "Push app images to ECR (${ENVS} / ${APPS}) - ch05/5.6" \
    --policy-document "$POLICY_DOC" >/dev/null
  echo "정책 생성: ${POLICY_NAME}"
fi

# ---------- 그룹: 없으면 만들고 정책 연결 ----------
if ! aws iam get-group --group-name "$GROUP" >/dev/null 2>&1; then
  aws iam create-group --group-name "$GROUP" >/dev/null
  echo "그룹 생성: ${GROUP}"
fi
aws iam attach-group-policy --group-name "$GROUP" --policy-arn "$POLICY_ARN"   # 이미 연결돼 있어도 오류 없음
echo "정책 연결: ${GROUP} ← ${POLICY_NAME}"

# ---------- 사용자를 그룹에 추가 ----------
for u in ${USERS[@]+"${USERS[@]}"}; do
  aws iam add-user-to-group --group-name "$GROUP" --user-name "$u"            # 이미 멤버여도 오류 없음
  echo "그룹 멤버 추가: ${u} → ${GROUP}"
done

echo
echo "허용된 리포지토리: ${ENVS//,/ } × ${APPS//,/ }  (계정 ${ACCOUNT_ID}, ${REGION})"
echo "개발자 확인: TF_VAR_env=dev scripts/push-images.sh was"
