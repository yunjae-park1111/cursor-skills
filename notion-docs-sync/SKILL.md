---
name: notion-docs-sync
description: Markdown 문서를 Notion에 동기화. .notion-sync.yaml 설정, Notion 동기화 실행 시 적용한다.
---

# Notion 문서 동기화

## 사전 요구사항

프로젝트에 `.notion-sync.yaml`이 없으면 사용자에게 배치할 폴더를 확인한 뒤(기본: 프로젝트 루트) `init.sh`를 실행한다.

```bash
SKILL_DIR/scripts/init.sh <target-dir>
```

`init.sh`가 수행하는 작업:
- `templates/` 파일을 대상 폴더에 복사 (이미 있으면 건너뜀)
- `spec/`, `guide/` 디렉토리 생성
- `npm install` 실행 (최초 1회, `node_modules` 없을 때만)

요구사항: Node.js 18+

스크립트(`sync.mjs`)는 스킬 디렉토리에 있으며 프로젝트에 복사하지 않는다. `.notion-sync.yaml`의 `file` 경로는 yaml 파일 기준 상대경로이다.

## Notion 동기화

- `docs/` 디렉토리의 `.md` 파일을 `sync.mjs`를 통해 Notion에 동기화한다.
- 문서 메타데이터는 `.notion-sync.yaml`에서 관리한다.
- 동기화 시 페이지 내용을 `erase_content`로 초기화한 뒤 블록을 다시 추가한다.
- 두 가지 동기화 방식을 지원한다:
  - `databases` — Notion DB 소속 문서. `Sync ID`로 페이지를 검색하고, 없으면 새로 생성한다.
  - `pages` — 독립 페이지. `page_id`로 직접 콘텐츠를 동기화한다.

### .notion-sync.yaml 구조

```yaml
databases:
  - database_id: "<Notion DB ID>"
    pages:
      - file: spec/api-design.md
        title: "API 설계 규칙"
        Sync ID: spec-api-design
        Parent: ""

pages:
  - file: guide/quickstart.md
    page_id: "<Notion Page ID>"
```

필드:
- `file` — `docs/` 기준 상대 경로
- `title` — Notion 페이지 제목 (`databases` 방식에서만 사용)
- `Sync ID` — 고유 식별자. `{분류}-{이름}` 형식 (예: `spec-api-design`, `guide-setup`)
- `Parent` — 상위 문서의 Sync ID. 빈 문자열이면 최상위
- `page_id` — Notion 페이지 ID (`pages` 방식에서만 사용)

예시 설정 파일: [templates/.notion-sync.yaml](templates/.notion-sync.yaml)

### 동기화 실행

`SKILL_DIR`은 이 스킬의 디렉토리 경로이다.

`NOTION_TOKEN` 환경변수가 필요하다. 설정되어 있지 않으면 사용자에게 Notion Integration Token을 요청한다.

```bash
# 전체 동기화 (CWD에 .notion-sync.yaml이 있을 때)
node SKILL_DIR/scripts/sync.mjs

# yaml 경로 지정
node SKILL_DIR/scripts/sync.mjs path/to/.notion-sync.yaml

# 특정 파일만
node SKILL_DIR/scripts/sync.mjs .notion-sync.yaml spec/api-design.md guide/setup.md
```

### Notion DB 요구 속성

Notion DB에 최소한 다음 속성이 필요하다:
- title 타입 속성 1개 (이름 자유, DB 스키마에서 자동 감지)
- `Sync ID` — rich_text 타입
- `Parent` — relation 타입 (자기 참조)

`.notion-sync.yaml`에 추가 속성을 넣으면 DB 스키마를 자동 조회하여 타입에 맞게 동기화한다. 지원 타입: rich_text, select, multi_select, number, checkbox, people, relation, date, url, email, phone_number

## 문서 작성 규칙

`init.sh` 실행 시 프로젝트에 복사되는 `NOTION-SYNC-GUIDE.md`에 디렉토리 구조, 문서 구조, 헤딩·파일명·본문 작성 규칙, 파일 첨부 방법이 정리되어 있다. 문서 작성 시 해당 가이드를 참조한다.
