#!/bin/bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
# 역할 잠금 설정 + 상태 in_progress 변경
# Usage: lock.sh <role-file> <pid>

ROLE_FILE="$1"
PID="$2"
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
LOCK_DIR="${ROLE_FILE%.md}.lock"

[ ! -f "$ROLE_FILE" ] && exit 1

# atomic lock 획득 (mkdir)
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # mkdir 실패 → pid 기록 대기 후 체크
  sleep 1
  LOCK_PID=""
  [ -f "$LOCK_DIR/pid" ] && LOCK_PID=$(cat "$LOCK_DIR/pid")
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "ERROR: $ROLE_FILE is locked by pid $LOCK_PID (alive)" >&2
    exit 1
  fi
  # dead process 또는 pid 미기록 → stale lock 정리 후 재시도
  rm -rf "$LOCK_DIR"
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "ERROR: $ROLE_FILE lock 획득 실패" >&2
    exit 1
  fi
fi

# pid를 lock 디렉토리에 즉시 기록
echo "$PID" > "$LOCK_DIR/pid"

# 잠금 설정
sed -i.bak "s/^- locked: .*/- locked: true/" "$ROLE_FILE"
sed -i.bak "s/^- locked_by: .*/- locked_by: $PID/" "$ROLE_FILE"
sed -i.bak "s/^- locked_at: .*/- locked_at: $NOW/" "$ROLE_FILE"

# 상태 변경
sed -i.bak "s/^- status: .*/- status: in_progress/" "$ROLE_FILE"

rm -f "${ROLE_FILE}.bak"
