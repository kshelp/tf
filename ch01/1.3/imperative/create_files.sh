#!/usr/bin/env bash
# 명령형(Imperative) 방식: "어떻게" 만들지 순서대로 명령한다.
# 실행할 때마다 현재 상태를 직접 확인하고 분기해야 멱등성이 보장된다.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)/out"
mkdir -p "$DIR"

for name in web was db; do
  file="$DIR/${name}.txt"
  if [[ -f "$file" ]]; then
    echo "skip   : $file (이미 존재)"
  else
    echo "server=${name}" > "$file"
    echo "create : $file"
  fi
done

# 목록에서 빠진 서버 파일을 지우려면 삭제 로직도 직접 작성해야 한다.
