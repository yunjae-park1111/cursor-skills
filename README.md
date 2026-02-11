# Cursor Agent Skills

Cursor AI 에이전트의 작업 능력을 확장하는 커스텀 스킬 모음입니다.

## 설치

```bash
git clone git@github.com:yunjae-park1111/cursor-skills.git ~/.cursor/skills
```

설치 후 Cursor가 자동으로 스킬을 인식합니다. 아래 User Rules 섹션을 Cursor User Rules에 추가하세요.

## 멀티 에이전트
- "병렬", "역할" 키워드가 포함되면 /agent-role 스킬을 참조한다.
- 모든 병렬 위임은 Cursor CLI(agent 명령, delegate.sh)로 통일한다.
- 하나의 역할 = 하나의 기능/시스템. 분석→수정→검증을 역할 내 파이프라인으로 수행한다.
- 메인은 오케스트레이터: 역할 문서 생성, 위임, 결과 수집만 수행한다.
- 역할 문서 기반 상태 관리를 위해 작업 난이도와 무관하게 스킬 절차를 따른다.

## 깃허브
- PR, 이슈, 커밋 키워드가 포함되면 /github-workflow 스킬을 참조한다.

## 스킬 관리
- ~/.cursor/skills/가 비어있거나 없으면 아래 레포에서 설치한다.
  - git clone git@github.com:yunjae-park1111/cursor-skills.git ~/.cursor/skills
- 스킬 업데이트가 필요하면 git pull로 갱신한다.

## 스킬 목록

| 스킬 | 설명 | 트리거 키워드 |
|------|------|--------------|
| [agent-role](#agent-role) | 멀티 에이전트 역할 기반 병렬 작업 관리 | 병렬, 역할, CLI, 백그라운드 |
| [github-workflow](#github-workflow) | GitHub PR, 이슈, 커밋 생성 및 관리 자동화 | PR, 이슈, 커밋 |

---

## agent-role

Cursor CLI(`agent` 명령)를 활용하여 여러 작업을 병렬로 위임·관리하는 스킬입니다.

### 핵심 개념

- **모듈 단위 역할**: 하나의 역할 = 하나의 모듈/시스템. 분석→수정→검증을 역할 내에서 파이프라인으로 수행
- **CLI 통일**: 모든 병렬 위임은 `delegate.sh`를 통해 Cursor CLI(`agent`)로 실행
- **메인은 오케스트레이터**: 역할 문서 생성, 위임, 결과 수집만 수행. 대상 파일을 직접 수정하지 않음

### 주요 기능

- **역할 문서 기반 병렬 위임**: `job-init.sh`로 역할 문서 생성 → `delegate.sh`로 Cursor CLI agent를 역할별 병렬 실행
- **자동 상태 관리**: lock.sh(in_progress) → unlock.sh(completed), 실패 시 delegate.sh가 failed로 자동 전환
- **동시 수정 방지**: 역할 문서에 PID 기반 lock/unlock으로 워커 간 충돌 방지
- **브라우저 대시보드**: 역할별 탭, 상태 표시, 로그 실시간 스트리밍(SSE), 정규식 필터, 로그 레벨 색상 구분. Node.js 필요
- **실패 자동 감지 및 재위임**: delegate.sh가 agent exit code로 실패 감지 → status=failed 전환. 메인이 로그/결과 확인 후 작업 수정하여 재위임
- **라운드 기반 반복**: 결과 수집 → 후속 판단 → 추가 작업이 필요하면 다음 라운드 역할 생성
- **세션 중단 이어받기**: `.done` 파일 존재 여부와 delegate PID 생존 상태로 마지막 단계를 판단하여 대기/수집/재위임 중 적절한 단계부터 재개

### 작업 구조

```
.agent/
└── job-{n}/
    ├── job.md          ← 작업 목적, 역할 테이블, 라운드별 결과 (메인만 수정)
    ├── role-1.md       ← 개별 역할 문서 (워커가 수정)
    ├── role-2.md
    ├── log-viewer.js   ← 브라우저 로그 뷰어 (job-init.sh가 자동 복사)
    └── log/
        ├── role-1.log  ← 역할별 agent 로그 (delegate.sh가 자동 생성)
        └── role-2.log
```

### 워크플로우

```
[메인 에이전트]
    │
    ├─ 1. job 폴더 생성 (.agent/job-{n}/)
    ├─ 2. job.md 작성 (목적, 역할 테이블)
    ├─ 3. role-{n}.md 작성 (각 역할별 작업 파이프라인)
    ├─ 4. delegate.sh로 병렬 위임
    ├─ 5. 완료 대기 (status.sh 폴링)
    ├─ 6. 결과 수집 및 검증
    ├─ 7. 실패 시 재시도
    └─ 8. 후속 판단 → 추가 라운드 또는 완료 보고
```

### 스크립트

| 스크립트 | 용도 |
|---------|------|
| `delegate.sh <role-file> [role-file2] ...` | CLI 병렬 위임. lock 자동 수행(agent PID 기록), 역할별 로그(job-dir/log/role-N.log) 저장, 실패 시 status=failed 자동 전환, job.md에 pid/started_at/ended_at 자동 기록 |
| `job-init.sh <job-dir> <goal> <target> [ref]` | job 구조 초기화 + 역할 문서 생성 (번호 자동, 테이블 자동 추가). 첫 호출 시 `PURPOSE=` 환경변수로 job 목적 설정 |
| `summary.sh [job-dir]` | 모든 역할의 결과 요약만 추출 (메인 결과 수집용) |
| `lock.sh <role-file> <pid>` | 잠금 + status: in_progress |
| `unlock.sh <role-file>` | 잠금 해제 + status: completed |
| `status.sh [job-dir]` | 개별 역할 문서 기반 실시간 상태 조회 |
| `parse-stream.js` | agent CLI의 stream-json 출력을 사람이 읽을 수 있는 형태로 실시간 변환. delegate.sh가 자동 사용 |
| `log-viewer.js` | 브라우저 로그 뷰어. delegate.sh가 자동 실행, 하트비트로 자동 종료. 수동: `node .agent/job-{n}/log-viewer.js [port]` |

### 역할 분할 예시

| 요청 | 역할 분할 |
|------|----------|
| "시크릿 관리랑 스토리지 동시에 점검해줘" | role-1: 시크릿 관리 체계, role-2: 스토리지 프로비저닝 |
| "CI/CD 파이프라인이랑 모니터링 개선해줘" | role-1: CI/CD 파이프라인, role-2: 모니터링/알림 체계 |
| "보안 감사하고 네트워크 정책 정리해줘" | role-1: 보안 감사, role-2: 네트워크 정책 |

---

## github-workflow

GitHub PR, 이슈, 커밋 작업을 자동화하는 스킬입니다.

### 핵심 개념

- **스크립트 기반 자동화**: PR/이슈 생성을 쉘 스크립트로 한 번에 처리
- **규칙 통일**: Conventional Commits, 브랜치 네이밍, PR 본문 템플릿을 일관되게 적용
- **프로젝트 연동**: 이슈 생성 시 GitHub Projects 필드(Sprint, Priority, Size)를 자동 설정

### 주요 기능

- **커밋 메시지**: Conventional Commits 규칙 (`<type>: <summary>`), 11개 타입 지원
- **브랜치 생성**: 이슈/에픽 번호 기반 자동 네이밍 (`issue/{N}`, `epic/{N}`)
- **PR 생성**: 브랜치명에서 이슈 번호 추출, 리모트 HEAD 기반 타겟 브랜치 결정, 푸시 상태 확인 후 자동 푸시, 6개 섹션 본문 템플릿 적용
- **이슈 생성**: GitHub Projects 자동 연결, Epic 서브이슈 연결(`gh sub-issue`), 현재 Sprint 자동 선택, Priority/Size 필드 자동 설정

### 스크립트

| 스크립트 | 용도 |
|---------|------|
| `create-pr.sh [issue_number] [target_branch]` | PR 생성 자동화. 이슈 번호 추출, 타겟 브랜치 결정, 푸시, PR 생성까지 한 번에 처리 |
| `create-issue.sh <title>` | 이슈 생성 자동화. 환경변수로 Epic 연결, 프로젝트 필드 설정 |

---

## 디렉토리 구조

```
~/.cursor/skills/
├── README.md
├── agent-role/
│   ├── SKILL.md
│   ├── scripts/
│   │   ├── delegate.sh
│   │   ├── job-init.sh
│   │   ├── lock.sh
│   │   ├── unlock.sh
│   │   ├── status.sh
│   │   ├── summary.sh
│   │   ├── parse-stream.js
│   │   └── log-viewer.js
│   └── templates/
│       └── README.md
├── github-workflow/
│   ├── SKILL.md
│   └── scripts/
│       ├── create-pr.sh
│       └── create-issue.sh
```

## 요구사항

- [Cursor IDE](https://cursor.com) (Agent 기능 활성화)
- Cursor CLI의 `agent` 명령 (agent-role 스킬, 병렬 위임 시 필요)
- [Node.js](https://nodejs.org/) (agent-role 스킬, 로그 뷰어/파서 실행 시 필요)
- [gh CLI](https://cli.github.com/) 2.0+ (github-workflow 스킬)
- gh extension: [yahsan2/gh-sub-issue](https://github.com/yahsan2/gh-sub-issue) (Epic 서브이슈 연결 시)

## 라이선스

MIT
