#!/bin/bash
# GitHub PR 생성 자동화
# Usage: create-pr.sh [issue_number] [target_branch]
#
# 이슈 번호를 인자로 받거나, 현재 브랜치에서 자동 추출한다.
# 타겟 브랜치를 인자로 받거나, 리모트 HEAD로 자동 결정한다.
#
# Options (환경변수):
#   PR_BODY - PR 본문 (미지정 시 기본 템플릿)

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

# 기존 PR 존재 확인
EXISTING_PR=$(gh pr list --head "$CURRENT_BRANCH" --base "$TARGET_BRANCH" --json number --jq '.[0].number' 2>/dev/null)

# 푸시 상태 확인
if ! git ls-remote --heads origin "$CURRENT_BRANCH" 2>/dev/null | grep -q .; then
  git push -u origin "$CURRENT_BRANCH"
else
  UNPUSHED=$(git log "origin/$CURRENT_BRANCH..$CURRENT_BRANCH" --oneline 2>/dev/null | wc -l | tr -d ' ')
  if [ "$UNPUSHED" -gt 0 ]; then
    git push -u origin "$CURRENT_BRANCH"
  fi
fi

# PR 타입 추출
FIRST_COMMIT_MSG=$(git log "$TARGET_BRANCH..$CURRENT_BRANCH" --format='%s' --reverse 2>/dev/null | head -1)
PR_TYPE=$(echo "$FIRST_COMMIT_MSG" | grep -oE '^[a-z]+' | head -1)
case "$PR_TYPE" in
  feat|fix|docs|refactor|style|test|chore|perf|ci|build|revert) ;;
  *) PR_TYPE="feat" ;;
esac

PR_TITLE="#$ISSUE_NUMBER $PR_TYPE: $ISSUE_TITLE"

# PR 본문
if [ -z "$PR_BODY" ]; then
  PR_BODY="## Issue?
Closes #$ISSUE_NUMBER

## Changes?

## Why we need?

## Test?

## CC (Optional)

## Anything else? (Optional)"
fi

# PR 생성 또는 수정
if [ -n "$EXISTING_PR" ]; then
  gh pr edit "$EXISTING_PR" --title "$PR_TITLE" --body "$PR_BODY"
  PR_URL=$(gh pr view "$EXISTING_PR" --json url --jq '.url')
  ACTION="updated"
else
  PR_URL=$(gh pr create --title "$PR_TITLE" --base "$TARGET_BRANCH" --body "$PR_BODY")
  ACTION="created"
fi

cat << PRINFO
ACTION=$ACTION
PR_URL=$PR_URL
ISSUE_NUMBER=$ISSUE_NUMBER
ISSUE_TITLE=$ISSUE_TITLE
TARGET_BRANCH=$TARGET_BRANCH
PR_TYPE=$PR_TYPE
PR_TITLE=$PR_TITLE
PRINFO
