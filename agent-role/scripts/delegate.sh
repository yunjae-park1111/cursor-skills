#!/bin/bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
# 여러 역할을 병렬로 CLI 에이전트에 위임
# Usage: delegate.sh <role-file1> <role-file2> [role-file3] ...
#
# 예시:
#   delegate.sh .agent/job-1/role-1.md .agent/job-1/role-2.md
#
# 완료 시 요약 출력:
#   OK 1
#   FAIL 2 (status=in_progress, exit=1, log=.agent/job-1/log/role-2.log)
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

  # 역할 문서에서 skills 필드 파싱 → SKILL.md 경로 목록 생성
  SKILL_NAMES=$(grep '^- skills:' "$ROLE_FILE" | sed 's/^- skills: *//')
  SKILL_INSTRUCTIONS=""
  if [ -n "$SKILL_NAMES" ]; then
    SKILL_INSTRUCTIONS="
아래 스킬이 이 작업에 필요하다. 작업 시작 전에 각 SKILL.md를 Read 도구로 읽고 절차를 따르라:"
    IFS=',' read -ra SKILL_ARR <<< "$SKILL_NAMES"
    for S in "${SKILL_ARR[@]}"; do
      S=$(echo "$S" | xargs)
      SKILL_PATH="$HOME/.cursor/skills/${S}/SKILL.md"
      if [ -f "$SKILL_PATH" ]; then
        SKILL_INSTRUCTIONS="${SKILL_INSTRUCTIONS}
- ${S}: ${SKILL_PATH}"
      fi
    done
  fi

  cat > "$PROMPT_FILE" <<PROMPT_EOF
다음 순서를 반드시 따라라:
- '## 현재 상태'와 '## Lock' 섹션은 직접 수정하지 않는다.
- lock은 delegate가 이미 수행했다. unlock.sh가 completed로 자동 변경한다.
- 작업 중 임시 파일이 필요하면 /tmp 에서 생성한다. 워크스페이스에 임시 파일을 만들지 않는다.
${SKILL_INSTRUCTIONS}
1. ${ROLE_FILE}를 읽는다.
2. 작업 섹션에 정의된 작업을 수행한다.
3. '결과 요약' 섹션에 한 줄 요약을 기록한다.
4. '결과' 섹션에 상세 결과를 기록한다.
5. '검증' 섹션에 반드시 실행한 검증 명령어와 실제 터미널 출력을 기록한다. 최소 3줄 이상의 실제 출력 스니펫을 포함해야 한다. "정상", "에러 없음" 같은 요약만 쓰면 안 된다.
6. '후속 제안' 섹션에 추가 작업이 필요하면 제안을 기록하고, 없으면 '없음'으로 기록한다.
7. '다음 세션 컨텍스트'를 기록한다.
8. ${SKILLS_DIR}/unlock.sh ${ROLE_FILE} 를 Shell로 실행한다.
PROMPT_EOF

  LOG_DIR="$(dirname "$ROLE_FILE")/log"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/$(basename "${ROLE_FILE%.md}").log"
  > "$LOG_FILE"
  script -q >(node "$SKILLS_DIR/parse-stream.js" "$LOG_FILE") agent -p --force --output-format stream-json --stream-partial-output --workspace "$WORKSPACE" "$(cat "$PROMPT_FILE")" &
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

# log-viewer 백그라운드 실행 (빈 포트 자동 탐색)
VIEWER="$JOB_DIR/log-viewer.js"
if [ -f "$VIEWER" ] && command -v node &>/dev/null; then
  VIEWER_PORT=$(node -e "const s=require('net').createServer();s.listen(0,()=>{console.log(s.address().port);s.close()})")
  node "$VIEWER" "$JOB_DIR" "$VIEWER_PORT" &
  VIEWER_PID=$!
  echo "Log Viewer: http://localhost:${VIEWER_PORT} (pid=$VIEWER_PID)"
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
    LOG_FILE="$(dirname "$ROLE_FILE")/log/$(basename "${ROLE_FILE%.md}").log"
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
