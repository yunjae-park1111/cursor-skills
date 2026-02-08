#!/bin/bash
# GitHub PR 생성 자동화
# Usage: create-pr.sh [issue_number] [target_branch]
#
# 이슈 번호를 인자로 받거나, 현재 브랜치에서 자동 추출한다.
# 타겟 브랜치를 인자로 받거나, 브랜치 규칙에 따라 자동 결정한다.

set -e

ISSUE_NUMBER="${1:-}"
TARGET_BRANCH_ARG="${2:-}"
CURRENT_BRANCH=$(git branch --show-current)

# 이슈 번호 추출
if [ -z "$ISSUE_NUMBER" ]; then
  ISSUE_NUMBER=$(echo "$CURRENT_BRANCH" | grep -oE '#?[0-9]+' | head -1 | tr -d '#')
fi

if [ -z "$ISSUE_NUMBER" ]; then
  echo "ERROR: 이슈 번호를 추출할 수 없습니다. 브랜치: $CURRENT_BRANCH" >&2
  exit 1
fi

# 이슈 존재 확인
if ! gh issue view "$ISSUE_NUMBER" --json title,number > /dev/null 2>&1; then
  echo "ERROR: 이슈 #$ISSUE_NUMBER 을(를) 찾을 수 없습니다." >&2
  exit 1
fi

ISSUE_TITLE=$(gh issue view "$ISSUE_NUMBER" --json title --jq '.title')

# 타겟 브랜치 결정: 인자 지정 시 해당 브랜치, 미지정 시 리모트 HEAD
if [ -n "$TARGET_BRANCH_ARG" ]; then
  TARGET_BRANCH="$TARGET_BRANCH_ARG"
else
  TARGET_BRANCH=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
fi

# 푸시 상태 확인
UNPUSHED=$(git log "origin/$CURRENT_BRANCH..$CURRENT_BRANCH" --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNPUSHED" -gt 0 ]; then
  git push -u origin "$CURRENT_BRANCH"
fi

# PR 타입 추출
PR_TYPE=$(echo "$CURRENT_BRANCH" | grep -oE '^[a-z]+' | head -1)
case "$PR_TYPE" in
  feat|fix|docs|refactor|enhance|style|test|chore) ;;
  *) PR_TYPE="feat" ;;
esac

# 출력: 에이전트가 이 정보로 PR 생성
cat << PRINFO
ISSUE_NUMBER=$ISSUE_NUMBER
ISSUE_TITLE=$ISSUE_TITLE
CURRENT_BRANCH=$CURRENT_BRANCH
TARGET_BRANCH=$TARGET_BRANCH
PR_TYPE=$PR_TYPE
PR_TITLE=#$ISSUE_NUMBER $PR_TYPE: $ISSUE_TITLE
PRINFO
