#!/bin/bash
# 역할 잠금 해제 + 상태 completed 변경
# Usage: unlock.sh <role-file>

ROLE_FILE="$1"
LOCK_DIR="${ROLE_FILE%.md}.lock"

[ ! -f "$ROLE_FILE" ] && exit 1

# lock 디렉토리 삭제
rm -rf "$LOCK_DIR" 2>/dev/null

# 잠금 해제
sed -i.bak "s/^- locked: .*/- locked: false/" "$ROLE_FILE"
sed -i.bak "s/^- locked_by: .*/- locked_by: -/" "$ROLE_FILE"
sed -i.bak "s/^- locked_at: .*/- locked_at: -/" "$ROLE_FILE"

# 상태 변경
sed -i.bak "s/^- status: .*/- status: completed/" "$ROLE_FILE"

rm -f "${ROLE_FILE}.bak"
