#!/usr/bin/env bash
# HCP Terraform API로 워크스페이스를 만들고 run을 시작하는 예시.
# 사용법: TFE_TOKEN=<token> ./create-workspace.sh <org> <workspace-name>
set -euo pipefail

ORG="${1:?organization}"
WS="${2:?workspace name}"
API="https://app.terraform.io/api/v2"
AUTH=(-H "Authorization: Bearer ${TFE_TOKEN:?set TFE_TOKEN}" -H "Content-Type: application/vnd.api+json")

# 1) 워크스페이스 생성
WS_ID=$(curl -sS "${AUTH[@]}" -X POST "$API/organizations/$ORG/workspaces" \
  -d "{\"data\":{\"type\":\"workspaces\",\"attributes\":{\"name\":\"$WS\",\"auto-apply\":false}}}" |
  jq -r '.data.id')
echo "workspace id: $WS_ID"

# 2) 워크스페이스 변수 등록
curl -sS "${AUTH[@]}" -X POST "$API/workspaces/$WS_ID/vars" \
  -d '{"data":{"type":"vars","attributes":{"key":"environment","value":"dev","category":"terraform"}}}' >/dev/null

# 3) 워크스페이스 조회
curl -sS "${AUTH[@]}" "$API/workspaces/$WS_ID" | jq '.data.attributes | {name, "execution-mode", "terraform-version"}'
