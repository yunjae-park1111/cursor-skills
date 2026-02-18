#!/bin/bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
# job 구조 초기화 + 역할 문서 생성
# Usage: job-init.sh <job-dir> <goal> <target> [ref]
#   PURPOSE 환경변수: 첫 호출 시 job.md의 ## 목적에 기록 (선택)
#
# 자동 처리:
#   - .agent/ 미존재 시 생성 + README.md 복사
#   - job-dir 미존재 시 생성 + job.md 기본 구조 생성 (PURPOSE= 반영)
#   - 역할 번호 자동 할당 (기존 role-*.md 기반)
#   - job.md 역할 테이블에 새 역할 행 자동 추가
#   - ref 경로 존재 검증
#
# 예시:
#   PURPOSE="인프라 점검" job-init.sh .agent/job-1 "ArgoCD 점검" "argo-apps/"
#   job-init.sh .agent/job-1 "Kyverno 점검" "helm/kyverno/" ".agent/job-1/role-1.md"

JOB_DIR="$1"
GOAL="$2"
TARGET="$3"
REF="$4"

[ -z "$JOB_DIR" ] || [ -z "$GOAL" ] || [ -z "$TARGET" ] && {
  echo "Usage: job-init.sh <job-dir> <goal> <target> [ref]"
  exit 1
}

# ref 경로 검증
[ -n "$REF" ] && [ ! -f "$REF" ] && {
  echo "ERROR: ref file not found: $REF"
  exit 1
}

# .agent/ 디렉토리 초기화
AGENT_DIR="${JOB_DIR%/job-*}"
if [ ! -d "$AGENT_DIR" ]; then
  mkdir -p "$AGENT_DIR"
  TEMPLATE="$HOME/.cursor/skills/agent-role/templates/README.md"
  [ -f "$TEMPLATE" ] && cp "$TEMPLATE" "$AGENT_DIR/README.md"
  echo "Initialized: $AGENT_DIR/"
fi

# job-dir 생성
if [ ! -d "$JOB_DIR" ]; then
  mkdir -p "$JOB_DIR"
  cat > "$JOB_DIR/log-viewer.js" <<'VIEWER_EOF'
#!/usr/bin/env node
require(require('path').join(process.env.HOME, '.cursor/skills/agent-role/scripts/log-viewer.js'));
VIEWER_EOF
  echo "Created: $JOB_DIR/"
fi

# job.md 기본 구조 생성 (없을 때만)
JOB_FILE="$JOB_DIR/job.md"
if [ ! -f "$JOB_FILE" ]; then
  cat > "$JOB_FILE" <<JOBEOF
# Job

## 목적
${PURPOSE:-}

## 역할
| ID | Round | Scope |
|----|-------|-------|

## Round 1
- goal:
- target:

### 작업

### Delegate
- pid:
- started_at:
- ended_at:

### 결과

### 후속 제안

## 다음 세션 컨텍스트
JOBEOF
  echo "Created: $JOB_FILE"
fi

# 역할 번호 자동 할당
MAX_NUM=$(ls "$JOB_DIR"/role-*.md 2>/dev/null | sed 's/.*role-\([0-9]*\)\.md/\1/' | sort -n | tail -1)
ROLE_NUM=$(( ${MAX_NUM:-0} + 1 ))
ROLE_FILE="$JOB_DIR/role-${ROLE_NUM}.md"

# 역할 문서 생성
REF_LINE=""
[ -n "$REF" ] && REF_LINE=$'\n'"- ref: $REF"

cat > "$ROLE_FILE" <<EOF
# Role: ${ROLE_NUM}

## Lock
- locked: false
- locked_by: -
- locked_at: -

## Scope
- goal: ${GOAL}
- target: ${TARGET}${REF_LINE}
- skills: ${SKILLS:-}

## 현재 상태
- status: idle

## 작업
1. **분석**: (분석 관점 체크리스트)
2. **수정**: (분석 결과에 따라 수정. 문제 없으면 건너뜀)
3. **검증**: (수정 결과 확인)

## 결과 요약

## 결과

## 검증

## 후속 제안

## 다음 세션 컨텍스트
EOF

# job.md 역할 테이블에 행 추가
CURRENT_ROUND=$(grep -o '^## Round [0-9]*' "$JOB_FILE" | tail -1 | awk '{print $NF}')
CURRENT_ROUND=${CURRENT_ROUND:-1}
SCOPE_SHORT=$(echo "$GOAL" | cut -c1-60)
TABLE_ROW="| role-${ROLE_NUM} | ${CURRENT_ROUND} | ${SCOPE_SHORT} |"
LAST_TABLE_LINE=$(grep -n '^|' "$JOB_FILE" | tail -1 | cut -d: -f1)
if [ -n "$LAST_TABLE_LINE" ]; then
  awk -v row="$TABLE_ROW" -v n="$LAST_TABLE_LINE" 'NR==n{print; print row; next}1' "$JOB_FILE" > "${JOB_FILE}.tmp" && mv "${JOB_FILE}.tmp" "$JOB_FILE"
fi

echo "Created: $ROLE_FILE (role-${ROLE_NUM})"
