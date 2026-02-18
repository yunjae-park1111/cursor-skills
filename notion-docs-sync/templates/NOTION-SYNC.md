# docs

Markdown → Notion 동기화 문서 디렉토리.

## Overview

스킬 레포: https://github.com/yunjae-park1111/cursor-skills (notion-docs-sync)

문서 형식(섹션 구조, 유형별 권장 구조)은 `tech-doc-guide` 스킬을 따른다. 이 문서에서는 Notion 동기화 시 지켜야 할 제약만 정의한다.

| 디렉토리 | 용도 |
|----------|------|
| `spec/` | 기획·명세 문서. 전략, 규칙, 정책, 구성 정의 |
| `guide/` | 실무 가이드 문서. 설정 절차, 운영 절차, 트러블슈팅 |

## Getting Started

`.notion-sync.yaml`이 있는 폴더를 기준으로 한다.

- 인덱스 파일은 하위 문서의 Parent 역할. `{주제}-index.md` 형식 (예: `spec/deploy-index.md`)
- 새 문서 추가 시 해당 디렉토리에 파일 생성 후 `.notion-sync.yaml`에 `Sync ID`와 `Parent` 등록
- `Sync ID` 형식: `{분류}-{이름}`. 접두사는 디렉토리에 따라 `spec-` 또는 `guide-`
  - 일반 문서: `spec-{이름}` (예: `spec-api-design`, `guide-deploy-process`)
  - 인덱스 문서: `{분류}-{주제}-index` (예: `spec-deploy-index`, `guide-ops-index`)

### 동기화 실행

```bash
export NOTION_TOKEN="<Notion Integration Token>"

# 전체 동기화 (CWD에 .notion-sync.yaml이 있을 때)
node ~/.cursor/skills/notion-docs-sync/scripts/sync.mjs

# yaml 경로 지정
node ~/.cursor/skills/notion-docs-sync/scripts/sync.mjs path/to/.notion-sync.yaml

# 특정 파일만
node ~/.cursor/skills/notion-docs-sync/scripts/sync.mjs .notion-sync.yaml spec/api-design.md guide/setup.md
```

## Usage

### .notion-sync.yaml

Markdown 파일과 Notion 페이지의 매핑을 관리한다.

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

#### 필드

| 필드 | 설명 |
|------|------|
| `file` | yaml 파일 기준 상대 경로 |
| `title` | Notion 페이지 제목 (필수). 동기화 시 페이지 제목을 업데이트한다 |
| `Sync ID` | 고유 식별자. `{분류}-{이름}` 형식 (예: `spec-api-design`) |
| `Parent` | 상위 문서의 Sync ID. 빈 문자열이면 최상위 |
| `page_id` | Notion 페이지 ID (`pages` 방식에서만 사용) |

#### 동기화 방식

| 방식 | 설명 |
|------|------|
| `databases` | Notion DB 소속 문서. `Sync ID`로 검색, 없으면 새로 생성 |
| `pages` | 독립 페이지. `page_id`로 직접 콘텐츠 동기화 |

#### Notion DB 요구 속성

- title 타입 속성 1개 (이름 자유, DB 스키마에서 자동 감지)
- `Sync ID` — rich_text 타입
- `Parent` — relation 타입 (자기 참조)

추가 속성을 넣으면 DB 스키마를 자동 조회하여 타입에 맞게 동기화한다.
지원 타입: rich_text, select, multi_select, number, checkbox, people, relation, date, url, email, phone_number

### 문서 구조

- 하위 문서 목록 — 상위 문서(인덱스)인 경우, 본문 마지막에 하위 문서 테이블 배치 (문서 | 파일 | 설명) 형식

### 문서 간 참조

- 상위/하위 관계는 `.notion-sync.yaml`의 `Parent` 필드로 정의. `""` (빈 문자열)이면 최상위
- 같은 디렉토리 내 참조: `[문서 제목](파일명)` (예: `[API 설계 규칙](api-design.md)`)
- 다른 디렉토리 참조: `[문서 제목](../spec/파일명)` 또는 `[문서 제목](../guide/파일명)`
- 외부 링크: `[텍스트](https://...)`
- 문서 제목은 `.notion-sync.yaml`의 `title`과 일치시킨다
- 같은 문서 내 섹션 참조는 사용하지 않는다 (Notion 변환 시 앵커 링크 미지원)

### 파일 첨부

- 마크다운 본문에서 `{{attach: 경로}}`를 사용하면 Notion 페이지에 파일 블록으로 삽입
- 경로: `~`(홈 디렉토리), 절대 경로, `docs/` 기준 상대 경로 모두 지원
- 플레이스홀더는 독립된 한 줄(paragraph)로 작성. 다른 텍스트와 같은 줄에 두지 않는다
- 리스트 아이템 하위에 넣으려면 2칸 들여쓰기 후 위아래 빈 줄로 분리 (리스트 아이템의 children 블록으로 변환)
- 파일이 존재하지 않으면 경고 후 건너뜀

## Configuration

### 파일명 규칙

- 영문 소문자 kebab-case (예: `api-design.md`, `deploy-process.md`)
- 확장자 `.md`만 허용
- 인덱스 파일: `{주제}-index.md` (예: `spec/deploy-index.md`, `guide/ops-index.md`)
- 파일명에 분류 접두사(`spec-`, `guide-`)를 붙이지 않는다. 접두사는 Sync ID에만 사용한다

| 구분 | 파일명 | Sync ID |
|------|--------|---------|
| 일반 문서 | `{이름}.md` | `{분류}-{이름}` |
| 인덱스 문서 | `{주제}-index.md` | `{분류}-{주제}-index` |
| 예시 (guide) | `ops-index.md` | `guide-ops-index` |
| 예시 (spec) | `deploy-index.md` | `spec-deploy-index` |

### 헤딩 규칙

| 레벨 | 규칙 |
|------|------|
| `#` | 사용 안 함. 제목은 `.notion-sync.yaml`의 `title`로 관리 |
| `##` | 대주제 섹션. 번호 없음 |
| `###` | 하위 항목. 모든 `###`에 번호 부여 (예: `### 1. 항목명`). `##`이 바뀌면 1부터 재시작 |
| `####` 이하 | 사용 안 함. 리스트로 표현 (예: `- **항목명**: 설명`) |

본문에서 순서 리스트(`1.`)와 함께 사용 가능. 헤딩 번호는 섹션 순서, 리스트 번호는 절차 순서로 구분한다.

### 본문 작성 규칙

- **리스트**: 비순서(`-`)와 순서(`1.`) 모두 사용 가능. 최대 2단계(루트 + 하위 1단계)만 허용 (Notion 변환 제한)
  - 허용: 루트 → 하위 (2단계)
  - 금지: 루트 → 하위 → 하위의 하위 (3단계 이상)
- **테이블**: 비교, 매트릭스, 옵션 나열 시 사용. 셀 내 줄바꿈 금지 (Notion 미지원)
- **코드 블록**: 언어 태그 필수 (```yaml, ```bash 등)
- **인용 블록**: `>` 사용 가능 (Notion quote 블록으로 변환)
- **이미지**: `![alt](url)` 형식 사용 가능
- **금지**: `---`(수평선), HTML, 같은 문서 내 앵커 링크
