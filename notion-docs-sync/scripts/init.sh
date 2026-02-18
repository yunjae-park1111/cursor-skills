#!/bin/bash
# docs 디렉토리 초기화
# Usage: init.sh <target-dir>
#   target-dir: .notion-sync.yaml과 docs를 배치할 폴더 (기본: CWD)

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="${1:-.}"

mkdir -p "$TARGET_DIR"

# templates 복사 (이미 있으면 건너뜀)
for f in "$SKILL_DIR/templates/"* "$SKILL_DIR/templates/".*; do
  [ ! -f "$f" ] && continue
  BASENAME="$(basename "$f")"
  [ -f "$TARGET_DIR/$BASENAME" ] && echo "Skip (exists): $BASENAME" && continue
  cp "$f" "$TARGET_DIR/$BASENAME"
  echo "Copied: $BASENAME"
done

# spec/, guide/ 디렉토리 생성
mkdir -p "$TARGET_DIR/spec" "$TARGET_DIR/guide"
echo "Created: spec/ guide/"

# npm install (node_modules 없을 때만)
if [ ! -d "$SKILL_DIR/scripts/node_modules" ]; then
  echo "Installing dependencies..."
  npm install --prefix "$SKILL_DIR/scripts"
fi

echo "Done: $TARGET_DIR"
