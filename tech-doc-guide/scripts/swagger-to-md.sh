#!/usr/bin/env bash
# swagger-to-md.sh - Swagger/OpenAPI 문서 관리 통합 스크립트
#
# 사용법:
#   swagger-to-md.sh <커맨드> <entrypoint> <swagger_출력> [md_출력]
#
# 커맨드:
#   install    swag CLI 설치
#   gen        OpenAPI 스펙 생성 (docs.go, swagger.json, swagger.yaml)
#   fmt        소스 코드의 Swagger 어노테이션 포맷팅
#   validate   어노테이션 유효성 검증
#   md         OpenAPI 스펙 → Markdown 변환 (gen 포함)
#   all        gen + md 한번에 실행
#
# 필수 인자:
#   entrypoint     main.go 경로 (예: cmd/control-plane/main.go)
#   swagger_출력    OpenAPI 스펙 출력 디렉토리 (예: ./docs/swagger)
#
# 선택 인자:
#   md_출력         Markdown 출력 디렉토리 (md/all 커맨드 시 필요, 예: ./docs/api)
#
# 경로는 스크립트 파일 기준 상대경로 또는 절대경로.
#
# 예시:
#   swagger-to-md.sh install
#   swagger-to-md.sh gen cmd/control-plane/main.go ./docs/swagger
#   swagger-to-md.sh md cmd/control-plane/main.go ./docs/swagger ./docs/api
#   swagger-to-md.sh all cmd/control-plane/main.go ./docs/swagger ./docs/api

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GOPATH_BIN="$(go env GOPATH 2>/dev/null)/bin"
[[ -d "$GOPATH_BIN" ]] && export PATH="${PATH}:${GOPATH_BIN}"

if ! which npx > /dev/null 2>&1; then
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
fi

resolve_path() {
  local p="$1"
  if [[ "$p" = /* ]]; then
    echo "$p"
  else
    echo "${SCRIPT_DIR}/${p}"
  fi
}

usage() {
  echo "사용법: swagger-to-md.sh <커맨드> <entrypoint> <swagger_출력> [md_출력]"
  echo ""
  echo "커맨드: install | gen | fmt | validate | md | all"
  exit 1
}

require_swag() {
  if ! which swag > /dev/null 2>&1; then
    echo "error: swag CLI가 설치되지 않았습니다. 'swagger-to-md.sh install' 실행"
    exit 1
  fi
}

require_npx() {
  if ! which npx > /dev/null 2>&1; then
    echo "error: npx가 설치되지 않았습니다. Node.js를 설치하세요."
    exit 1
  fi
}

# --- 후처리 파이프라인 (tech-doc-guide 형식 변환) ---

html_to_md() {
  sed -E \
    -e 's|^<h1 id="[^"]*">(.*)</h1>$|# \1|' \
    -e 's|^<h2 id="[^"]*">(.*)</h2>$|## \1|' \
    -e 's|^<h3 id="[^"]*">(.*)</h3>$|### \1|'
}

remove_noise() {
  sed \
    -e '/^<!-- /d' \
    -e '/^<a id="/d' \
    -e '/^<aside /d' \
    -e '/^This operation does not require authentication$/d' \
    -e '/^<\/aside>$/d' \
    -e '/^> Scroll down for code samples/d' \
    -e '/^> Code samples$/d' \
    -e '/^> Example responses$/d'
}

rewrite_header() {
  awk -v auto_gen='> `swagger.yaml`에서 자동 생성됨 (`make swagger-md`)' \
      -v overview_heading='## 개요' '
    BEGIN { in_header = 1; title = ""; desc = "" }
    in_header && /^# / && title == "" { title = $0; next }
    in_header && /^# / && title != "" {
      print title; print ""; print auto_gen; print ""
      if (desc != "") { print overview_heading; print ""; print desc; print "" }
      in_header = 0; print $0; next
    }
    in_header && !/^$/ && !/^#/ && !/^\*/ && !/^Base URLs/ && !/^Email:/ && !/^License:/ && !/^>/ {
      if (desc == "") desc = $0; next
    }
    in_header { next }
    { print }
  '
}

# 앵커 링크 제거 (Notion 미지원): [Text](#anchor) → Text
remove_anchor_links() {
  perl -pe 's/\[([^\]]+)\]\(#[^)]+\)/$1/g'
}

[[ $# -lt 1 ]] && usage

CMD="$1"
shift

cmd_install() {
  echo "Installing swag CLI..."
  which swag > /dev/null 2>&1 || go install github.com/swaggo/swag/cmd/swag@latest
  echo "swag CLI installed successfully!"
  swag --version
}

cmd_gen() {
  [[ $# -lt 2 ]] && { echo "error: gen에는 <entrypoint> <swagger_출력> 인자가 필요합니다."; usage; }
  require_swag
  local entry="$(resolve_path "$1")"
  local out="$(resolve_path "$2")"
  mkdir -p "$out"
  cd "$SCRIPT_DIR"
  swag init -g "$1" -o "$out" --parseDependency --parseInternal
  echo "Swagger 문서 생성 완료: ${out}"
}

cmd_fmt() {
  require_swag
  cd "$SCRIPT_DIR"
  swag fmt
  echo "Swagger 포맷팅 완료"
}

cmd_validate() {
  [[ $# -lt 2 ]] && { echo "error: validate에는 <entrypoint> <swagger_출력> 인자가 필요합니다."; usage; }
  require_swag
  local tmp_dir="/tmp/swagger-validate-$$"
  cd "$SCRIPT_DIR"
  swag init -g "$1" -o "$tmp_dir" --parseDependency --parseInternal
  rm -rf "$tmp_dir"
  echo "Swagger validation passed!"
}

cmd_md() {
  [[ $# -lt 3 ]] && { echo "error: md에는 <entrypoint> <swagger_출력> <md_출력> 인자가 필요합니다."; usage; }
  require_npx
  local entry="$1"
  local swagger_dir="$(resolve_path "$2")"
  local md_dir="$(resolve_path "$3")"
  local md_file="${md_dir}/api-spec.md"
  local tmp_file
  tmp_file="$(mktemp)"

  cmd_gen "$entry" "$2"

  mkdir -p "$md_dir"
  npx widdershins "${swagger_dir}/swagger.yaml" -o "$tmp_file" \
    --summary --language_tabs 'shell:Shell' 'go:Go' --omitHeader

  cat "$tmp_file" \
    | html_to_md \
    | remove_noise \
    | rewrite_header \
    | remove_anchor_links \
    | cat -s \
    > "$md_file"

  rm -f "$tmp_file"
  echo "API Markdown 문서 생성 완료: ${md_file}"
}

cmd_all() {
  cmd_md "$@"
}

case "$CMD" in
  install)  cmd_install ;;
  gen)      cmd_gen "$@" ;;
  fmt)      cmd_fmt ;;
  validate) cmd_validate "$@" ;;
  md)       cmd_md "$@" ;;
  all)      cmd_all "$@" ;;
  *)        echo "error: 알 수 없는 커맨드: ${CMD}"; usage ;;
esac
