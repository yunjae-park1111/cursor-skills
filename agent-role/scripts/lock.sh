#!/bin/bash
# 역할 잠금 설정 + 상태 in_progress 변경
# Usage: lock.sh <role-file> <pid>

ROLE_FILE="$1"
PID="$2"
NOW=$(date '+%Y-%m-%d %H:%M')

[ ! -f "$ROLE_FILE" ] && exit 1

# 현재 잠금 상태 확인
LOCKED=$(grep '^- locked: ' "$ROLE_FILE" | awk '{print $NF}')
if [ "$LOCKED" = "true" ]; then
  LOCK_PID=$(grep '^- locked_by:' "$ROLE_FILE" | awk '{print $NF}')
  if kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "ERROR: $ROLE_FILE is locked by pid $LOCK_PID (alive)" >&2
    exit 1
  fi
fi

# 잠금 설정
sed -i.bak "s/^- locked: .*/- locked: true/" "$ROLE_FILE"
sed -i.bak "s/^- locked_by: .*/- locked_by: $PID/" "$ROLE_FILE"
sed -i.bak "s/^- locked_at: .*/- locked_at: $NOW/" "$ROLE_FILE"

# 상태 변경
sed -i.bak "s/^- status: .*/- status: in_progress/" "$ROLE_FILE"

rm -f "${ROLE_FILE}.bak"
