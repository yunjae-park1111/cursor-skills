#!/bin/bash
# 여러 역할을 병렬로 CLI 에이전트에 위임
# Usage: delegate.sh <role-file1> <role-file2> [role-file3] ...
#
# 예시:
#   delegate.sh .agent/job-1/role-1.md .agent/job-1/role-2.md
#
# 완료 시 요약 출력:
#   OK 1
#   FAIL 2 (status=in_progress, exit=1, log=/tmp/role-2.log)
#   ---
#   total=2 completed=1 failed=1
#
# job.md 자동 기록:
#   - pid, started_at: 위임 시작 시 자동 기록
#   - ended_at: 모든 워커 완료 후 자동 기록

[ $# -eq 0 ] && echo "역할 파일을 1개 이상 지정해야 합니다" && exit 1

WORKSPACE="$(pwd)"
SKILLS_DIR="$HOME/.cursor/skills/agent-role/scripts"
PIDS=()
ROLE_FILES=()
PROMPT_FILES=()

# job.md 필드 자동 기록: 마지막 빈 필드 행을 찾아 값 채우기
update_job_field() {
  local FILE="$1" FIELD="$2" VALUE="$3"
  local LINE
  LINE=$(grep -n "^- ${FIELD}: *$" "$FILE" | tail -1 | cut -d: -f1)
  if [ -n "$LINE" ]; then
    sed -i.bak "${LINE}s/.*/- ${FIELD}: ${VALUE}/" "$FILE"
    rm -f "${FILE}.bak"
  fi
}

for ROLE_FILE in "$@"; do
  [ ! -f "$ROLE_FILE" ] && continue
  ROLE_FILES+=("$ROLE_FILE")

  PROMPT_FILE=$(mktemp)
  PROMPT_FILES+=("$PROMPT_FILE")

  cat > "$PROMPT_FILE" <<PROMPT_EOF
다음 순서를 반드시 따라라:
- '## 현재 상태'와 '## Lock' 섹션은 직접 수정하지 않는다.
- lock은 delegate가 이미 수행했다. unlock.sh가 completed로 자동 변경한다.
1. ${ROLE_FILE}를 읽는다.
2. 작업 섹션에 정의된 작업을 수행한다.
3. '결과 요약' 섹션에 한 줄 요약을 기록한다.
4. '결과' 섹션에 상세 결과를 기록한다.
5. '검증' 섹션에 반드시 실행한 검증 명령어와 실제 터미널 출력을 기록한다. 최소 3줄 이상의 실제 출력 스니펫을 포함해야 한다. "정상", "에러 없음" 같은 요약만 쓰면 안 된다.
6. '후속 제안' 섹션에 추가 작업이 필요하면 제안을 기록하고, 없으면 '없음'으로 기록한다.
7. '다음 세션 컨텍스트'를 기록한다.
8. ${SKILLS_DIR}/unlock.sh ${ROLE_FILE} 를 Shell로 실행한다.
PROMPT_EOF

  LOG_FILE="/tmp/$(basename "${ROLE_FILE%.md}").log"
  agent -p --force --workspace "$WORKSPACE" "$(cat "$PROMPT_FILE")" > "$LOG_FILE" 2>&1 &
  AGENT_PID=$!
  PIDS+=("$AGENT_PID")

  # delegate에서 직접 lock (agent 프로세스 PID 기록)
  "$SKILLS_DIR/lock.sh" "$ROLE_FILE" "$AGENT_PID"

  sleep 1
done

# job.md에 pid, started_at 자동 기록
JOB_DIR=$(dirname "${ROLE_FILES[0]}")
JOB_FILE="$JOB_DIR/job.md"
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

if [ -f "$JOB_FILE" ]; then
  update_job_field "$JOB_FILE" "pid" "$$"
  update_job_field "$JOB_FILE" "started_at" "$NOW"
fi

COMPLETED=0
FAILED=0

for i in "${!PIDS[@]}"; do
  wait "${PIDS[$i]}" 2>/dev/null
  CODE=$?
  ROLE_FILE="${ROLE_FILES[$i]}"
  STATUS=$(grep '^- status:' "$ROLE_FILE" | awk '{print $NF}')
  ROLE_ID=$(basename "$ROLE_FILE" .md | sed 's/^role-//')

  if [ "$STATUS" = "completed" ] && [ "$CODE" -eq 0 ]; then
    echo "OK $ROLE_ID"
    ((COMPLETED++))
  else
    LOG_FILE="/tmp/$(basename "${ROLE_FILE%.md}").log"
    echo "FAIL $ROLE_ID (status=$STATUS, exit=$CODE, log=$LOG_FILE)"
    rm -rf "${ROLE_FILE%.md}.lock" 2>/dev/null
    sed -i.bak "s/^- status: .*/- status: failed/" "$ROLE_FILE"
    sed -i.bak "s/^- locked: .*/- locked: false/" "$ROLE_FILE"
    sed -i.bak "s/^- locked_by: .*/- locked_by: -/" "$ROLE_FILE"
    sed -i.bak "s/^- locked_at: .*/- locked_at: -/" "$ROLE_FILE"
    rm -f "${ROLE_FILE}.bak"
    ((FAILED++))
  fi
done

# 임시 파일 정리
for f in "${PROMPT_FILES[@]}"; do rm -f "$f"; done

# job.md에 ended_at 자동 기록
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
if [ -f "$JOB_FILE" ]; then
  update_job_field "$JOB_FILE" "ended_at" "$NOW"
fi

SUMMARY="total=${#ROLE_FILES[@]} completed=$COMPLETED failed=$FAILED"
echo "---"
echo "$SUMMARY"

# 완료 시그널 파일 생성 (job 폴더에 .done)
echo "$SUMMARY" > "$JOB_DIR/.done"

exit "$FAILED"
