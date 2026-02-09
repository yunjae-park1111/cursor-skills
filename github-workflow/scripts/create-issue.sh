#!/bin/bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
# GitHub 이슈 생성 및 프로젝트 연결 자동화
# Usage: create-issue.sh <title>
#
# Options (환경변수):
#   EPIC_NUMBER    - Epic 이슈 번호 (서브이슈로 연결)
#   EPIC_REPO      - Epic이 있는 레포 (크로스 레포 시)
#   ISSUE_BODY     - 이슈 본문 (기본: 빈 문자열)
#   PROJECT_NUMBER - 프로젝트 번호 (선택)
#   PRIORITY       - Priority: P0/P1/P2 (기본: P1)
#   SIZE           - Size: XS/S/M/L/XL (기본: S)
#   STATUS         - Status (기본: Todo)

set -e

TITLE="${1:-}"
[ -z "$TITLE" ] && echo "ERROR: 제목을 지정해야 합니다." >&2 && exit 1

OWNER=$(gh repo view --json owner --jq '.owner.login')
CURRENT_REPO=$(gh repo view --json name --jq '.name')
TARGET_REPO="${EPIC_REPO:-$CURRENT_REPO}"
STATUS="${STATUS:-Todo}"
SIZE="${SIZE:-S}"
PRIORITY="${PRIORITY:-P1}"

# 이슈 생성
ISSUE_URL=$(gh issue create --title "$TITLE" --body "${ISSUE_BODY:-}" --assignee @me --json url --jq '.url' 2>/dev/null || \
  gh issue create --title "$TITLE" --body "${ISSUE_BODY:-}" --assignee @me | tail -1)
ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')

# Epic 서브이슈 연결
if [ -n "$EPIC_NUMBER" ]; then
  if ! gh extension list 2>/dev/null | grep -q 'sub-issue'; then
    echo "WARN: gh sub-issue 확장이 설치되어 있지 않습니다. 'gh extension install yahsan2/gh-sub-issue'로 설치하세요." >&2
  fi
  if [ "$TARGET_REPO" = "$CURRENT_REPO" ]; then
    gh sub-issue add "$EPIC_NUMBER" "$ISSUE_NUMBER" 2>/dev/null || true
  else
    EPIC_URL="https://github.com/$OWNER/$TARGET_REPO/issues/$EPIC_NUMBER"
    gh sub-issue add "$EPIC_URL" "$ISSUE_URL" 2>/dev/null || true
  fi
fi

# 프로젝트 연결 (PROJECT_NUMBER 지정 시)
ITEM_ID=""
PROJECT_ID=""
if [ -n "$PROJECT_NUMBER" ]; then
  gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$ISSUE_URL" 2>/dev/null || true

  FIELDS=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json 2>/dev/null)
  ITEM_ID=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json 2>/dev/null | \
    jq -r "first(.items[] | select(.content.url == \"$ISSUE_URL\")) | .id")
  PROJECT_ID=$(gh project view "$PROJECT_NUMBER" --owner "$OWNER" --format json 2>/dev/null | jq -r '.id')

  if [ -z "$ITEM_ID" ]; then
    echo "WARN: 프로젝트에서 아이템을 찾을 수 없습니다. 필드 설정을 건너뜁니다." >&2
  else
    # 헬퍼 함수
    field_id() { echo "$FIELDS" | jq -r ".fields[] | select(.name == \"$1\") | .id"; }
    option_id() { echo "$FIELDS" | jq -r ".fields[] | select(.name == \"$1\") | .options[] | select(.name == \"$2\") | .id"; }

    set_select() {
      [ -z "$2" ] && return 0
      local FID OID
      FID=$(field_id "$1")
      OID=$(option_id "$1" "$2")
      [ -z "$FID" ] || [ -z "$OID" ] && return 0
      gh project item-edit --id "$ITEM_ID" --field-id "$FID" --project-id "$PROJECT_ID" --single-select-option-id "$OID" 2>/dev/null || true
    }

    # 필드 설정
    set_select "Status" "$STATUS"
    set_select "Priority" "$PRIORITY"
    set_select "Size" "$SIZE"

    # Sprint: 최신 iteration 자동 설정
    SPRINT_FIELD_ID=$(echo "$FIELDS" | jq -r '.fields[] | select(.type == "ProjectV2IterationField") | .id')
    SPRINT_ITERATION_ID=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit 1 2>/dev/null | \
      jq -r 'first(.items[] | to_entries[] | select(.value | type == "object" and has("iterationId")) | .value) | .iterationId')

    [ -n "$SPRINT_FIELD_ID" ] && [ -n "$SPRINT_ITERATION_ID" ] && [ "$SPRINT_ITERATION_ID" != "null" ] && \
      gh project item-edit --id "$ITEM_ID" --field-id "$SPRINT_FIELD_ID" --project-id "$PROJECT_ID" --iteration-id "$SPRINT_ITERATION_ID" 2>/dev/null || true
  fi
fi

# 출력
cat << ISSUEINFO
ISSUE_NUMBER=$ISSUE_NUMBER
ISSUE_URL=$ISSUE_URL
EPIC_NUMBER=${EPIC_NUMBER:-}
PROJECT_NUMBER=${PROJECT_NUMBER:-}
ISSUEINFO
