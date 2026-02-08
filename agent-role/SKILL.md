---
name: agent-role
description: 멀티 에이전트 역할 기반 작업 관리 및 CLI 병렬 위임. 병렬, 역할 키워드에서 사용한다.
---

# Agent Role Management

## 구조

```
.agent/
└── job-{n}/
    ├── job.md                ← 목적, 역할 테이블, 라운드별 결과 (메인 + 스크립트가 수정)
    ├── role-1.md             ← 개별 역할 문서
    └── role-2.md
```

- job-{n}: 작업 단위. `job-init.sh`가 자동 생성한다.

## 핵심 원칙

- **모듈 단위 역할**: 하나의 역할 = 하나의 모듈/시스템. 분석→수정→검증을 역할 내에서 파이프라인으로 수행한다.
- **CLI 통일**: 모든 병렬 위임은 CLI agent(delegate.sh)를 사용한다. 분석/수정을 분리하지 않는다.
- **메인은 오케스트레이터**: 작업 정의(`## 작업` 체크리스트), 위임, 결과 수집만 수행한다. 대상 파일을 직접 수정하지 않는다. 읽기(glob, grep, read 등)는 허용한다.

## 스크립트

| 스크립트 | 용도 |
|---------|------|
| `delegate.sh <role-file> [role-file2] ...` | CLI 병렬 위임. lock 자동 수행(agent PID 기록), 역할별 로그(/tmp/role-N.log) 저장, 실패 시 status=failed 자동 전환, job.md에 pid/started_at/ended_at 자동 기록 |
| `job-init.sh <job-dir> <goal> <target> [ref]` | job 구조 초기화 + 역할 문서 생성 (번호 자동, 테이블 자동 추가). 첫 호출 시 `PURPOSE=` 환경변수로 job 목적 설정 |
| `summary.sh [job-dir]` | 모든 역할의 결과 요약만 추출 (메인 결과 수집용) |
| `lock.sh <role-file> <pid>` | 잠금 + status: in_progress |
| `unlock.sh <role-file>` | 잠금 해제 + status: completed |
| `status.sh [job-dir]` | 개별 역할 문서 기반 실시간 상태 조회 |

경로 prefix: `~/.cursor/skills/agent-role/scripts/`

## 메인 에이전트 동작

### 일반 작업
- 메인이 직접 수행한다.
- `job-init.sh`로 역할 문서를 생성하고, `lock.sh`로 잠금 후 작업을 시작한다.
- 작업 중 진행 상황을 역할 문서에 수시로 갱신한다.
- 완료 시 결과/다음 컨텍스트를 기록하고 `unlock.sh`로 잠금을 해제한다.

### 병렬 작업 (사용자가 "병렬로", "CLI로", "백그라운드로" 요청 시)

**금지: 메인은 작업 정의, 위임, 결과 수집만 수행한다. 분석, 구현, 리뷰 등 실제 작업을 절대 직접 수행하지 않는다.**
**중요: 모든 단계를 한 턴 안에서 중단 없이 수행한다. 중간에 사용자에게 응답하지 않는다.**

1. **역할 문서 생성**: 각 역할별 `job-init.sh`로 생성 (.agent/, job-dir, job.md, 역할 테이블 자동 처리)
   - 첫 번째 역할 생성 시 `PURPOSE="..."` 환경변수로 job 목적을 함께 설정한다
   - job.md Round의 goal/target을 채운다
   - 역할 문서의 `## 작업`에 파이프라인 단계를 순서대로 정의한다 (예: 1.분석 2.수정 3.검증)
   - 각 단계의 구체적 관점/체크리스트를 명시한다
   - "분석해줘"처럼 막연한 지시 금지
2. **CLI 위임 실행**: `delegate.sh`로 위임 (Shell block_until_ms: 0으로 백그라운드)
3. **완료 대기** (같은 턴에서 즉시 시작, 끊지 않는다):
   a. delegate.sh가 job.md의 pid/started_at을 자동 기록하므로 별도 기록 불필요
   b. Shell로 아래 명령을 실행한다 (block_until_ms를 충분히 높게 설정. 예: 600000):
      ```
      SCRIPTS=~/.cursor/skills/agent-role/scripts
      while [ ! -f .agent/job-{n}/.done ]; do sleep 10; $SCRIPTS/status.sh .agent/job-{n}; done
      cat .agent/job-{n}/.done && rm .agent/job-{n}/.done
      ```
   c. 출력된 요약(total/completed/failed)을 확인한다. ended_at도 delegate.sh가 자동 기록한다
4. **결과 수집** (루프 종료 직후 즉시 수행):
   a. `summary.sh`로 전체 역할 요약을 한 번에 확인한다 (역할이 많을 때 유용)
   b. `## 검증` 섹션 확인 — 명령어+실제 출력 스니펫(3줄 이상)이 있으면 재검증 생략, 불충분하면 메인이 직접 재검증
   c. 필요 시 `## 결과` 상세 내용 읽기
   d. delegate.sh가 역할 문서의 status를 자동 갱신한다 (completed/failed + lock 해제). 메인은 job.md 역할 테이블만 갱신
   e. job.md의 해당 Round에 `### 결과`, `### 후속 제안`을 각 역할 문서를 분석·판단하여 기록한다 (단순 복붙 금지, 메인이 판단하여 정리)
5. **실패 재시도** (failed가 1건 이상일 때):
   a. 실패한 역할의 `/tmp/role-N.log`와 `## 결과` 섹션을 읽어 실패 원인을 진단한다
   b. 원인에 따라 역할 문서의 `## 작업`을 수정한다 (체크리스트 보강, 범위 축소 등)
   c. status를 idle로 초기화하고 delegate.sh로 재위임한다
   d. 3~4단계를 반복한다
   e. 재시도도 실패하면 넘어간다
6. **후속 판단**:
   a. 해당 Round의 결과와 후속 제안을 확인한다
   b. 추가 작업이 필요하면 job.md에 다음 Round 섹션 추가 + `job-init.sh`로 역할 생성 → 1번으로
   c. 불필요하면 job.md `## 다음 세션 컨텍스트`를 최종 정리하고 사용자에게 결과 보고한다

**모든 단계가 완료된 후에만 사용자에게 응답한다.**

### 중단 이어받기

세션이 중단된 후 새 세션에서 이어받을 때:

1. `.agent/job-{n}/job.md`를 읽어 마지막 Round 상태를 확인한다
2. `.agent/job-{n}/.done` 파일 존재 여부를 확인한다
   - 없음 + delegate PID alive → 3단계(완료 대기 루프)부터 이어간다
   - 없음 + delegate PID dead → 역할 문서 status로 판단하여 결과 수집 또는 재위임
   - 있음 → 4단계(결과 수집)부터 이어간다

## job.md

`job-init.sh`로 생성. 첫 호출 시 `PURPOSE=` 환경변수로 목적이 자동 기록된다. 메인은 Round의 goal/target을 채운다.

- **역할 테이블**: job-init.sh가 역할 추가 시 자동 갱신. 역할 문서의 status는 delegate.sh(lock→in_progress, 실패→failed)와 워커(unlock→completed)가 자동 관리. 메인은 job.md 테이블만 갱신.
- **Delegate**: pid/started_at/ended_at은 delegate.sh가 자동 기록.
- **결과/후속 제안**: 메인이 역할 문서를 분석·판단하여 기록 (단순 복붙 금지).

## 개별 역할 문서 (role-{n}.md)

`job-init.sh`로 생성. 메인은 `## 작업` 섹션만 채우면 된다.

- **Scope**: goal(목적), target(대상), ref(참조 역할 경로, 선택)
- **작업**: 분석→수정→검증 파이프라인. 구체적 체크리스트 필수
- **검증**: 명령어 + 실제 터미널 출력 3줄 이상 필수. "정상", "에러 없음" 같은 요약만 쓰면 안 됨

## 역할 예시

| 예시 요청 | 역할 분할 |
|----------|----------|
| "시크릿 관리랑 스토리지 동시에 점검해줘" | role-1: 시크릿 관리 체계, role-2: 스토리지 프로비저닝 |
| "CI/CD 파이프라인이랑 모니터링 개선해줘" | role-1: CI/CD 파이프라인, role-2: 모니터링/알림 체계 |
| "보안 감사하고 네트워크 정책 정리해줘" | role-1: 보안 감사, role-2: 네트워크 정책 |

사용자가 범위를 지정하지 않으면 메인이 기능 단위로 적절히 나눈다.

