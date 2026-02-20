---
name: tech-doc-guide
description: 기술 문서 형식 가이드. 문서 작성, 문서 형식, README, Spec, 가이드 키워드에서 사용한다.
---

# 기술 문서 형식 가이드

## 사전 요구사항

문서 자동 생성 스크립트(`### 9. 코드 문서화`) 사용 시:

| 스크립트 | 도구 | 코드 세팅 |
|----------|------|-----------|
| `godoc-to-md.sh` | `gomarkdoc` | 패키지 주석이 godoc 형식으로 작성 (`#### Go 패키지 주석 양식` 참조) |
| `swagger-to-md.sh` | `swag`, `npx` | entrypoint에 API 메타 어노테이션, 핸들러에 라우트 어노테이션 |
| `schema-to-md.sh` | 없음 | `migrations/*.up.sql` 파일 존재 |

도구 설치:
- `go install github.com/princjef/gomarkdoc/cmd/gomarkdoc@latest`
- `go install github.com/swaggo/swag/cmd/swag@latest`
- Node.js (`npx`)

## 절차

문서를 작성하거나 수정할 때, 대상 문서의 유형을 판단하고 해당 형식을 적용한다.

### 1. 문서 유형 판단

| 유형 | 판단 기준 |
|------|-----------|
| README | 프로젝트 또는 디렉토리의 소개/안내 문서 |
| 인덱스 | 디렉토리의 하위 문서 목록과 탐색 경로를 제공하는 목차 문서 |
| 스킬 문서 (SKILL.md) | Cursor 에이전트가 읽고 따라갈 지시 문서 |
| 프로젝트 Spec | 목표, 아키텍처, 기능, 연동을 정의하는 명세 |
| 정책/규칙 Spec | 팀 또는 시스템이 따라야 하는 기준을 명문화하는 명세 |
| 프로세스/구조 Spec | 반복 수행되는 흐름이나 시스템 구조를 정의하는 명세 |
| 가이드 (How-to) | 특정 목표를 달성하기 위한 절차 |

### 2. README 형식 적용

**근거**: GitHub 생태계 사실상 표준.

```markdown
# 프로젝트명
한 줄 설명

## Overview
## Getting Started
  - Prerequisites
  - Installation
  - Quick Start
## Usage
## Configuration
## Contributing
## License
```

하위 디렉토리 README는 해당되는 섹션만 사용한다 (Overview → Usage → Configuration 등).

### 3. 인덱스 형식 적용

**근거**: 디렉토리 내 문서 탐색을 위한 엔트리포인트.

```markdown
## 개요
한두 줄로 이 디렉토리가 다루는 범위를 설명한다.

## 하위 문서
| 문서 | 파일 | 설명 |
```

- 필요 시 카테고리별로 테이블을 분리한다 (예: Spec 문서 테이블, 가이드 문서 테이블)
- 링크는 상대 경로를 사용한다

### 4. 스킬 문서 (SKILL.md) 형식 적용

**근거**: Cursor Skills 공식 형식.

```markdown
---
name: 스킬명
description: 한 줄 설명. WHAT(기능)과 WHEN(트리거) 포함. 3인칭.
compatibility:
  - 의존성 1
---

# 스킬명

## 사전 요구사항

## 절차
  1. ...
  2. ...

## 참조
- 상세 내용은 [reference.md](reference.md) 참조
```

- 500줄 이내
- 지시문으로 작성 (설명이 아닌 절차)
- 에이전트가 이미 아는 건 쓰지 않는다
- 상세 내용은 별도 파일로 분리 (1단계까지만)

### 5. 프로젝트 Spec 형식 적용

**근거**: 공식 표준 없음. ISO/IEC/IEEE 42010, arc42 참고.

```markdown
## 개요

## 목표
  - 현재: 구현된 상태
  - 최종: 향후 달성할 목표

## 아키텍처
  - 시스템 구조 (다이어그램 또는 텍스트)
  - 기술 스택과 선택 근거

## 주요 기능
| 기능 | 설명 |

## 외부 연동
| 대상 시스템 | 연동 방식 | 용도 |

## 제약 사항
  - 성능, 보안, 확장성 등 비기능 요구사항
```

- `## 목표`에서 현재 구현된 상태와 최종 목표를 구분한다
- `## 외부 연동`은 해당 프로젝트 고유의 연동이 있을 때만 사용한다. 하위 컴포넌트에서 다루는 경우 생략할 수 있다

### 6. 정책/규칙 Spec 형식 적용

**근거**: 공식 표준 없음. ISO 27001 정책 구조, IETF RFC 2119 참고.

```markdown
## 개요

## 카테고리명 1
### 1. 규칙/항목
### 2. 규칙/항목

## 카테고리명 2
### 1. 규칙/항목

## 예외
```

- 규칙을 카테고리별 `##` 섹션으로 분리하고, 각 섹션 내에서 `###` 번호 항목이나 테이블로 기술한다
- `## 예외`는 선택 섹션이다

### 7. 프로세스/구조 Spec 형식 적용

**근거**: 공식 표준 없음. BPMN 2.0, RACI 매트릭스 참고.

```markdown
## 개요

## 구성 / 흐름
  - 구조 문서: 시스템 구성 요소와 관계
  - 프로세스 문서: 단계별 흐름 (다이어그램 또는 번호 목록)
```

- `## 개요`와 핵심 내용 섹션은 필수이다
- 아래 섹션은 문서 특성에 따라 **해당되는 것만** 선택하여 사용한다:

| 선택 섹션 | 사용 시점 |
|-----------|-----------|
| `## 구성 요소` | 시스템/컴포넌트의 역할과 관계를 정의할 때 |
| `## 흐름` / `## 절차` | 단계별 프로세스가 있을 때 |
| `## 트리거와 조건` | 시작/종료 조건이 명확할 때 |
| `## 예외` | 예외 케이스나 실패 시나리오가 있을 때 |

### 8. 가이드 (How-to) 형식 적용

**근거**: DITA task 구조(OASIS 표준) 참고.

```markdown
## 개요

## 사전 조건

## 절차
  1. ...
  2. ...

## 검증

## 트러블슈팅
```

### 9. 코드 문서화

- **패키지/함수**: godoc (코드 주석 기반 자동 생성). Go 공식 표준.
- **REST API**: swaggo/swag (코드 주석 → OpenAPI/Swagger 스펙 자동 생성). 별도 yaml을 수동 작성하지 않는다.

#### Go 패키지 주석 양식

패키지 주석은 Core File (`{패키지명}.go`)의 `package` 선언 바로 위에 작성한다.
첫 문단은 `Package {name}` 으로 시작하고, godoc `# Heading` 문법으로 섹션을 구분한다.

| heading | 설명 | 필수 |
|---------|------|------|
| (첫 문단) | 패키지 개요 (`Package {name} ...`) | ✅ |
| `# File Structure` | 파일 구조와 각 파일 역할 | ✅ |
| `# Components` | 핵심 구조체, 인터페이스, 관계 | ✅ |
| `# Configuration` | 설정 상수, 환경변수 | 해당 시 |
| `# Usage` | 사용 예시 코드 | ✅ |

패키지 특성에 따라 heading을 추가한다 (예: `# Message Flow`, `# Connection Flow`, `# Shutdown`).

#### 문서 자동 생성 스크립트

스킬의 `SKILL_DIR/scripts/`에 3개의 문서 생성 스크립트가 포함되어 있다.
모든 스크립트의 경로 인자는 스크립트 파일 기준 상대경로 또는 절대경로.

| 스크립트 | 소스 | 출력 | 의존성 |
|---------|------|------|--------|
| `godoc-to-md.sh` | Go 패키지 godoc 주석 | 패키지별 `.md` | `gomarkdoc` |
| `swagger-to-md.sh` | Swagger 어노테이션 | `api-spec.md` | `swag`, `npx` (widdershins) |
| `schema-to-md.sh` | `migrations/*.up.sql` | `db-schema.md` | 없음 |

**1. godoc-to-md.sh** — Go 패키지 주석 → Markdown

gomarkdoc으로 godoc 주석에서 마크다운을 추출한다.
패키지 설명만 추출할 때는 `## Index` 이전까지만 취한다.
heading 레벨을 조정하고(`###` → `##`), 프로세스/구조 Spec 형식에 맞게 한글 매핑한다:

| godoc heading | 문서 heading |
|---------------|-------------|
| `# File Structure` | `## 파일 구조` |
| `# Components` | `## 구성 요소` |
| `# Configuration` | `## 설정` |
| `# Usage` | `## 사용 예시` |

```bash
SKILL_DIR/scripts/godoc-to-md.sh <프로젝트_루트> <문서_디렉토리> [-f 필터]

# 예시
SKILL_DIR/scripts/godoc-to-md.sh /path/to/project /path/to/project/docs
SKILL_DIR/scripts/godoc-to-md.sh /path/to/project /path/to/project/docs -f agent/client
```

**2. swagger-to-md.sh** — Swagger 어노테이션 → OpenAPI 스펙 + Markdown

소스 코드에 swaggo 어노테이션이 작성되어 있어야 한다:

- **entrypoint** (main.go): API 메타 정보 (`@title`, `@version`, `@description`, `@BasePath` 등)
- **핸들러 함수**: 라우트 어노테이션 (`@Summary`, `@Tags`, `@Param`, `@Success`, `@Failure`, `@Router`)

`md` 커맨드는 widdershins 출력을 후처리하여 HTML 태그 제거, `## 개요` 삽입 등 tech-doc-guide 형식으로 변환한다.

서브커맨드로 설치/생성/포맷/검증/변환을 통합 관리한다.

| 커맨드 | 설명 |
|--------|------|
| `install` | swag CLI 설치 |
| `gen` | OpenAPI 스펙 생성 (docs.go, swagger.json, swagger.yaml) |
| `fmt` | 소스 코드의 Swagger 어노테이션 포맷팅 |
| `validate` | 어노테이션 유효성 검증 |
| `md` | gen + OpenAPI → Markdown 변환 |
| `all` | md와 동일 |

```bash
SKILL_DIR/scripts/swagger-to-md.sh <커맨드> <entrypoint> <swagger_출력> [md_출력]

# 예시
SKILL_DIR/scripts/swagger-to-md.sh install
SKILL_DIR/scripts/swagger-to-md.sh gen cmd/control-plane/main.go ./docs/swagger
SKILL_DIR/scripts/swagger-to-md.sh md cmd/control-plane/main.go ./docs/swagger ./docs/api
```

**3. schema-to-md.sh** — SQL 마이그레이션 → DB 스키마 Markdown

`migrations/*.up.sql` 파일이 존재해야 한다. 표준 SQL 문법(`CREATE TABLE`, `CREATE INDEX`, `REFERENCES`)을 파싱하여 테이블/컬럼/인덱스/ER 다이어그램을 생성한다. DB 연결 불필요.

```bash
SKILL_DIR/scripts/schema-to-md.sh <마이그레이션_디렉토리> <문서_디렉토리>

# 예시
SKILL_DIR/scripts/schema-to-md.sh ./migrations ./docs/api
```

**Makefile 통합 패턴:**

프로젝트에 스크립트를 복사한 뒤 Makefile로 통합하면 `make docs` 한 커맨드로 전체 문서를 생성할 수 있다.

```makefile
docs: swagger-md schema-md
	@./godoc-to-md.sh . ./docs
```

## 공통 원칙

1. **제목은 내용을 즉시 드러낸다**
2. **Why → What → How 순서**
3. **예시가 반드시 포함된다**
4. **유지보수할 수 있는 범위 내에서만 작성한다**
5. **변경 이력은 Git으로 관리한다**
6. **`## 개요`에 레포지토리를 명시한다** — `- **레포지토리**: \`org/repo-name\`` 형식. 여러 레포에 걸치면 복수 표기
