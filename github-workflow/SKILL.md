---
name: github-workflow
description: GitHub PR, 이슈, 커밋 생성 및 관리 자동화. PR, 이슈, 커밋, 깃허브 키워드에서 사용한다.
compatibility:
  - gh cli 2.0+
  - gh extension: yahsan2/gh-sub-issue
---

# GitHub Workflow

## 사전 요구사항

`gh sub-issue` 확장이 없으면 설치한다:

```bash
gh extension install yahsan2/gh-sub-issue
```

GitHub PR, 이슈, 커밋 작업 시 이 스킬을 따른다.

## 브랜치 생성

| 종류 | 형식 | 예시 |
|------|------|------|
| 이슈 | `issue/{ISSUE}` | issue/#12 |
| 에픽 | `epic/{ISSUE}` | epic/#11 |

## 커밋 메시지 (Conventional Commits)

형식: `<type>: <summary>`

```
feat: add user authentication system

- GitHub OAuth 2.0 PKCE 플로우 구현
- JWT 토큰 기반 인증 미들웨어 추가
- 사용자 세션 관리 기능
```

### 타입

| 타입 | 설명 |
|------|------|
| feat | 새로운 기능 추가 |
| fix | 버그 수정 |
| docs | 문서 변경 |
| style | 코드 포맷팅 |
| refactor | 코드 리팩토링 |
| perf | 성능 개선 |
| test | 테스트 코드 |
| build | 빌드 시스템/외부 종속성 변경 |
| ci | CI 설정 변경 |
| chore | 기타 변경 |
| revert | 이전 커밋 되돌리기 |

### 규칙

- Summary: 영어 명령문, 50자 이내, 마침표 없음
- 제목과 본문 사이 빈 줄
- 본문: 불릿 형식, 72자마다 줄바꿈, 한국어 또는 영어

## PR

### 제목

형식: `#<ISSUE_NUMBER> <type>: <summary>` (영어)

예시: `#123 feat: add user authentication system`

### 본문

```markdown
## Issue?

## Changes?

## Why we need?

## Test?

## CC (Optional)

## Anything else? (Optional)
```

### 타겟 브랜치

| 조건 | 타겟 |
|------|------|
| 기본 | 리모트 HEAD 브랜치 |
| 직접 지정 | 두 번째 인자로 타겟 브랜치 지정 |

### 머지 전략

| 경로 | 전략 |
|------|------|
| 이슈 → dev | Squash |
| release → main | Merge |

### 생성

`scripts/create-pr.sh [issue_number] [target_branch]`를 실행한다. 이슈 번호 추출, 타겟 브랜치 결정, 푸시, PR 생성까지 한 번에 처리한다. `PR_BODY` 환경변수로 본문을 지정할 수 있다.

## 이슈

### 생성

`scripts/create-issue.sh <title>`를 실행한다. 환경변수로 옵션을 지정한다.

| 환경변수 | 설명 |
|----------|------|
| `EPIC_NUMBER` | Epic 이슈 번호 (서브이슈로 연결) |
| `EPIC_REPO` | Epic이 있는 레포 (크로스 레포 시) |
| `ISSUE_BODY` | 이슈 본문 |
| `PROJECT_NUMBER` | 프로젝트 번호 (지정 시 프로젝트 연결 + 필드 설정) |
| `PRIORITY` | Priority (미지정 시 에이전트 자율 판단) |
| `SIZE` | Size (기본: S) |
| `STATUS` | Status (기본: Todo) |
| `ESTIMATE` | Estimate (기본: 1) |

### 주의사항

- assignee는 항상 @me
- Epic 서브이슈는 `gh sub-issue`로 parent-child 관계 설정
- 크로스 레포 이슈는 `EPIC_REPO` 환경변수로 지정
