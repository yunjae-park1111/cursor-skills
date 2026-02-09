#!/bin/bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
# 모든 역할의 결과 요약만 추출 (메인이 빠르게 판단하기 위한 용도)
# Usage: summary.sh [job-dir]
#
# 출력 예시:
#   [job-1]
#   role-1 [completed]: 8개 체크리스트 분석, 4건 수정 완료
#   role-2 [completed]: 5건 결함 수정, helm template 렌더링 정상
#   role-3 [in_progress]: (요약 없음)

AGENT_DIR=".agent"

if [ -n "$1" ]; then
  JOB_DIR="$1"
else
  JOB_DIR=$(ls -d "$AGENT_DIR"/job-* 2>/dev/null | sort -t- -k2 -n | tail -1)
fi

[ -z "$JOB_DIR" ] || [ ! -d "$JOB_DIR" ] && echo "job 폴더가 없습니다" && exit 1

echo "[$(basename "$JOB_DIR")]"

for f in "$JOB_DIR"/role-*.md; do
  [ -f "$f" ] || continue
  ID=$(basename "$f" .md | sed 's/^role-//')
  STATUS=$(grep '^- status:' "$f" | awk '{print $NF}')

  # ## 결과 요약 섹션의 내용 추출 (다음 ## 까지)
  SUMMARY=$(awk '/^## 결과 요약/{found=1; next} /^## /{found=0} found && NF' "$f" | head -3)

  if [ -n "$SUMMARY" ]; then
    echo "role-${ID} [${STATUS}]: ${SUMMARY}"
  else
    echo "role-${ID} [${STATUS}]: (요약 없음)"
  fi
done
