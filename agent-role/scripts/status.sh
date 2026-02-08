#!/bin/bash
# 개별 역할 문서 기반 실시간 상태 조회
# Usage: status.sh [job-dir]
#   job-dir 지정 시 해당 job만, 미지정 시 최신 job 조회
#
# 출력 예시:
#   [job-1]
#   1: status=completed locked=false
#   2: status=in_progress locked=true (pid=12345, alive)
#   ---
#   total=2 completed=1 in_progress=1 idle=0 failed=0

AGENT_DIR=".agent"

if [ -n "$1" ]; then
  JOB_DIRS=("$1")
else
  JOB_DIRS=($(ls -d "$AGENT_DIR"/job-* 2>/dev/null | sort -t- -k2 -n | tail -1))
fi

[ ${#JOB_DIRS[@]} -eq 0 ] && echo "job 폴더가 없습니다" && exit 1

for JOB_DIR in "${JOB_DIRS[@]}"; do
  echo "[$(basename "$JOB_DIR")]"

  TOTAL=0
  COMPLETED=0
  IN_PROGRESS=0
  IDLE=0
  FAILED=0

  for f in "$JOB_DIR"/role-*.md; do
    [ -f "$f" ] || continue
    ((TOTAL++))

    ID=$(basename "$f" .md | sed 's/^role-//')
    STATUS=$(grep '^- status:' "$f" | awk '{print $NF}')
    LOCKED=$(grep '^- locked: ' "$f" | awk '{print $NF}')

    LINE="$ID: status=$STATUS locked=$LOCKED"

    if [ "$LOCKED" = "true" ]; then
      PID=$(grep '^- locked_by:' "$f" | awk '{print $NF}')
      if [ "$PID" != "-" ] && kill -0 "$PID" 2>/dev/null; then
        LINE="$LINE (pid=$PID, alive)"
      elif [ "$PID" != "-" ]; then
        LINE="$LINE (pid=$PID, dead)"
      fi
    fi

    echo "$LINE"

    case "$STATUS" in
      completed) ((COMPLETED++)) ;;
      in_progress) ((IN_PROGRESS++)) ;;
      idle) ((IDLE++)) ;;
      failed) ((FAILED++)) ;;
    esac
  done

  echo "---"
  echo "total=$TOTAL completed=$COMPLETED in_progress=$IN_PROGRESS idle=$IDLE failed=$FAILED"
done
