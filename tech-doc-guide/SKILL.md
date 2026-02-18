---
name: tech-doc-guide
description: 기술 문서 형식 가이드. 문서 작성, 문서 형식, README, Spec, 가이드 키워드에서 사용한다.
---

# 기술 문서 형식 가이드

## 사전 요구사항

없음.

## 절차

문서를 작성하거나 수정할 때, 대상 문서의 유형을 판단하고 해당 형식을 적용한다.

### 1. 문서 유형 판단

| 유형 | 판단 기준 |
|------|-----------|
| README | 프로젝트 또는 디렉토리의 소개/안내 문서 |
| 스킬 문서 (SKILL.md) | Cursor 에이전트가 읽고 따라갈 지시 문서 |
| 프로젝트 Spec | 목표, 아키텍처, 기능, 연동을 정의하는 명세 |
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

### 3. 스킬 문서 (SKILL.md) 형식 적용

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

### 4. 프로젝트 Spec 형식 적용

**근거**: 공식 표준 없음. ISO/IEC/IEEE 42010, arc42 참고.

```markdown
## 개요

## 목표
  - 이 프로젝트가 해결하는 문제
  - 핵심 가치/목적

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

개별 주제(정책, 규칙 등)의 spec 문서는 개요만 고정하고 본문은 주제에 따라 자유롭게 구성한다.

### 5. 가이드 (How-to) 형식 적용

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

### 6. 코드 문서화

- **패키지/함수**: godoc (코드 주석 기반 자동 생성). Go 공식 표준.
- **REST API**: swaggo/swag (코드 주석 → OpenAPI/Swagger 스펙 자동 생성). 별도 yaml을 수동 작성하지 않는다.

## 공통 원칙

1. **제목은 내용을 즉시 드러낸다**
2. **Why → What → How 순서**
3. **예시가 반드시 포함된다**
4. **유지보수할 수 있는 범위 내에서만 작성한다**
