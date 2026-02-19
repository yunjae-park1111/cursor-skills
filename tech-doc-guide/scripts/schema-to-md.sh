#!/usr/bin/env bash
# schema-to-md.sh - migrations/*.up.sql → Markdown DB 스키마 문서 자동 생성
#
# 사용법:
#   schema-to-md.sh <마이그레이션_디렉토리> <문서_디렉토리>
#
# 필수 인자:
#   마이그레이션_디렉토리   SQL 마이그레이션 파일이 있는 디렉토리
#   문서_디렉토리           마크다운 문서 출력 디렉토리
#
# 경로는 스크립트 파일 기준 상대경로 또는 절대경로.
#
# 예시:
#   schema-to-md.sh ./migrations ./docs/api
#   schema-to-md.sh /abs/path/migrations /abs/path/docs/api

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "error: 필수 인자 부족"
  echo "사용법: schema-to-md.sh <마이그레이션_디렉토리> <문서_디렉토리>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

resolve_path() {
  local p="$1"
  if [[ "$p" = /* ]]; then
    echo "$p"
  else
    echo "${SCRIPT_DIR}/${p}"
  fi
}

MIGRATIONS_DIR="$(resolve_path "$1")"
OUTPUT_DIR="$(resolve_path "$2")"
OUTPUT_FILE="${OUTPUT_DIR}/db-schema.md"

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "error: 마이그레이션 디렉토리를 찾을 수 없습니다: ${MIGRATIONS_DIR}"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

ALL_SQL=""
for f in "${MIGRATIONS_DIR}"/*.up.sql; do
  [ -f "$f" ] && ALL_SQL+="$(cat "$f")"$'\n'
done

if [ -z "$ALL_SQL" ]; then
  echo "error: ${MIGRATIONS_DIR}에 *.up.sql 파일이 없습니다."
  exit 1
fi

# 개요 정보 수집
table_count="$(echo "$ALL_SQL" | grep -ciE '^CREATE TABLE' || true)"
index_count="$(echo "$ALL_SQL" | grep -ciE '^CREATE INDEX' || true)"
fk_count="$(echo "$ALL_SQL" | grep -ci 'REFERENCES' || true)"

{
  echo "# DB 스키마"
  echo ""
  echo "> \`migrations/*.up.sql\`에서 자동 생성됨 (\`make schema-md\`)"
  echo ""
  echo "## 개요"
  echo ""
  echo "테이블 ${table_count}개, 인덱스 ${index_count}개, FK 관계 ${fk_count}개로 구성된 스키마."
  echo ""

  in_table=0
  table_name=""
  col_idx=0
  constraints=""

  while IFS= read -r raw_line; do
    line="$(echo "$raw_line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"

    # CREATE TABLE
    if echo "$line" | grep -qiE '^CREATE TABLE'; then
      table_name="$(echo "$line" | sed -E 's/CREATE TABLE[[:space:]]+(IF NOT EXISTS[[:space:]]+)?([a-zA-Z_]+).*/\2/')"
      in_table=1
      col_idx=0
      constraints=""
      echo "## 테이블: \`${table_name}\`"
      echo ""
      echo "| # | 컬럼 | 타입 | 제약조건 |"
      echo "|---|------|------|----------|"
      continue
    fi

    # End of table
    if [ "$in_table" -eq 1 ] && echo "$line" | grep -qE '^\);'; then
      in_table=0
      if [ -n "$constraints" ]; then
        echo ""
        echo "**테이블 제약조건:**"
        echo ""
        echo "$constraints"
      fi
      echo ""
      continue
    fi

    # Inside table
    if [ "$in_table" -eq 1 ]; then
      [ -z "$line" ] && continue

      # Remove trailing comma
      line="$(echo "$line" | sed 's/,$//')"

      # Table-level constraints
      if echo "$line" | grep -qiE '^(UNIQUE|CHECK|FOREIGN KEY|CONSTRAINT)'; then
        constraints="${constraints}- \`${line}\`"$'\n'
        continue
      fi

      col_idx=$((col_idx + 1))

      col_name="$(echo "$line" | awk '{print $1}')"
      rest="$(echo "$line" | sed -E "s/^${col_name}[[:space:]]+//")"

      type_str=""
      constraint_str=""

      if echo "$rest" | grep -qiE '(PRIMARY KEY|NOT NULL|DEFAULT|REFERENCES|UNIQUE)'; then
        type_str="$(echo "$rest" | sed -E 's/[[:space:]]*(PRIMARY KEY|NOT NULL|DEFAULT|REFERENCES|UNIQUE).*//')"
        constraint_str="$(echo "$rest" | sed -E 's/^[A-Za-z0-9_()]+[[:space:]]*//')"
      else
        type_str="$rest"
      fi

      [ -z "$constraint_str" ] && constraint_str="-"

      echo "| ${col_idx} | \`${col_name}\` | \`${type_str}\` | ${constraint_str} |"
    fi

  done <<< "$ALL_SQL"

  # Indexes
  indexes="$(echo "$ALL_SQL" | grep -iE '^CREATE INDEX' || true)"
  if [ -n "$indexes" ]; then
    echo "## 인덱스"
    echo ""
    echo "| 인덱스명 | 테이블 | 컬럼 |"
    echo "|----------|--------|------|"
    echo "$indexes" | while IFS= read -r line; do
      idx_name="$(echo "$line" | sed -E 's/CREATE INDEX[[:space:]]+(IF NOT EXISTS[[:space:]]+)?([a-zA-Z_]+).*/\2/')"
      tbl_name="$(echo "$line" | sed -E 's/.*[[:space:]]ON[[:space:]]+([a-zA-Z_]+).*/\1/')"
      col_expr="$(echo "$line" | sed 's/;$//' | grep -oE '\([^)]+\)$' | tr -d '()')"
      echo "| \`${idx_name}\` | \`${tbl_name}\` | \`${col_expr}\` |"
    done
    echo ""
  fi

  # ER diagram (Mermaid)
  tables="$(echo "$ALL_SQL" | grep -ioE 'CREATE TABLE[[:space:]]+(IF NOT EXISTS[[:space:]]+)?[a-zA-Z_]+' | awk '{print $NF}')"
  fk_lines="$(echo "$ALL_SQL" | grep -i 'REFERENCES' || true)"

  if [ -n "$tables" ]; then
    echo "## ER 다이어그램"
    echo ""
    echo "\`\`\`mermaid"
    echo "erDiagram"

    er_in_table=0
    er_table_name=""
    while IFS= read -r raw_line; do
      line="$(echo "$raw_line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"

      if echo "$line" | grep -qiE '^CREATE TABLE'; then
        er_table_name="$(echo "$line" | sed -E 's/CREATE TABLE[[:space:]]+(IF NOT EXISTS[[:space:]]+)?([a-zA-Z_]+).*/\2/')"
        er_in_table=1
        echo "    ${er_table_name} {"
        continue
      fi

      if [ "$er_in_table" -eq 1 ] && echo "$line" | grep -qE '^\);'; then
        er_in_table=0
        echo "    }"
        continue
      fi

      if [ "$er_in_table" -eq 1 ]; then
        [ -z "$line" ] && continue
        line="$(echo "$line" | sed 's/,$//')"
        echo "$line" | grep -qiE '^(UNIQUE|CHECK|FOREIGN KEY|CONSTRAINT)' && continue

        col_name="$(echo "$line" | awk '{print $1}')"
        rest="$(echo "$line" | sed -E "s/^${col_name}[[:space:]]+//")"
        type_str="$(echo "$rest" | sed -E 's/[[:space:]]*(PRIMARY KEY|NOT NULL|DEFAULT|REFERENCES|UNIQUE).*//' | sed 's/([^)]*)//g')"

        marker=""
        echo "$rest" | grep -qi 'PRIMARY KEY' && marker=" PK"
        echo "$rest" | grep -qi 'REFERENCES' && marker=" FK"

        echo "        ${type_str} ${col_name}${marker}"
      fi
    done <<< "$ALL_SQL"

    echo ""

    if [ -n "$fk_lines" ]; then
      echo "$fk_lines" | while IFS= read -r line; do
        child_col="$(echo "$line" | awk '{print $1}')"
        parent="$(echo "$line" | sed -E 's/.*REFERENCES[[:space:]]+([a-zA-Z_]+).*/\1/')"
        child_table="$(echo "$ALL_SQL" | grep -B100 "$line" | grep -ioE 'CREATE TABLE[[:space:]]+(IF NOT EXISTS[[:space:]]+)?[a-zA-Z_]+' | tail -1 | awk '{print $NF}')"
        echo "    ${parent} ||--o{ ${child_table} : \"${child_col}\""
      done
    fi

    echo "\`\`\`"
    echo ""
  fi

} > "$OUTPUT_FILE"

echo "DB 스키마 문서 생성 완료: ${OUTPUT_FILE}"
