# .agent

멀티 에이전트 역할 기반 작업 관리 디렉토리.
스킬 레포: https://github.com/yunjae-park1111/cursor-skills (agent-role)

`.gitignore`에 추가를 권장합니다.

## 구조

job-{n}/ — 작업 단위 (`job-init.sh`가 자동 생성)

### job.md (메인 + 스크립트가 수정)
| 섹션 | 내용 | 수정 주체 |
|------|------|-----------|
| 목적 | 이번 작업의 최종 목적 | job-init.sh(PURPOSE=, 첫 호출), 메인 |
| 역할 | ID/Round/Scope 테이블 | job-init.sh(추가) |
| Round N > goal/target | 이 라운드의 목적과 범위 | 메인 |
| Round N > 작업 | 이 라운드에서 각 역할이 수행할 작업 요약 | 메인 |
| Round N > Delegate | pid, 시작/종료 시각 | delegate.sh(자동 기록) |
| Round N > 결과 | 메인이 판단하여 정리한 라운드 결과 | 메인 |
| Round N > 후속 제안 | 의미 있는 후속 제안만 선별 | 메인 |
| 다음 세션 컨텍스트 | 최종 라운드 기준, 이어받기용 핵심 정보 | 메인 |

### role-{n}.md (워커가 수정)
| 섹션 | 내용 |
|------|------|
| Lock | 동시 수정 방지. lock.sh/unlock.sh가 자동 관리 |
| Scope | goal(최종 목적), target(대상), ref(참고할 역할 문서 경로) |
| 현재 상태 | status 값 (lock.sh → in_progress, unlock.sh → completed) |
| 작업 | 파이프라인 단계별 체크리스트 (분석→수정→검증) |
| 결과 요약 | 한 줄 요약 (summary.sh가 추출, 메인이 빠르게 파악용) |
| 결과 | 상세 작업 결과 |
| 검증 | 검증 명령어 + 실제 출력 스니펫 3줄 이상 필수 |
| 후속 제안 | 자기 범위 밖의 추가 작업 제안. 없으면 '없음' |
| 다음 세션 컨텍스트 | 이어서 작업할 때 필요한 정보 |

### 스크립트
| 스크립트 | 용도 |
|---------|------|
| `job-init.sh` | job 구조 초기화 + 역할 문서 생성 (번호 자동, 테이블 자동 추가, 첫 호출 시 PURPOSE= 반영) |
| `delegate.sh` | CLI 병렬 위임 + job.md에 pid/started_at/ended_at 자동 기록 |
| `summary.sh` | 모든 역할의 결과 요약 추출 |
| `status.sh` | 실시간 상태 조회 |
| `lock.sh` | 잠금 + status: in_progress |
| `unlock.sh` | 잠금 해제 + status: completed |
| `parse-stream.js` | stream-json 출력을 읽기 가능한 형태로 실시간 변환 (delegate.sh가 자동 사용) |
| `log-viewer.js` | 브라우저 로그 뷰어 (delegate.sh가 자동 실행, 하트비트로 자동 종료) |

### Status 값
| 값 | 의미 |
|----|------|
| idle | 생성됨, 아직 시작 안 함 |
| in_progress | 워커가 작업 중 (lock.sh가 설정) |
| completed | 작업 완료 (unlock.sh가 설정) |
| failed | 작업 실패 (delegate.sh가 자동 설정 또는 메인이 수동 설정) |

### log/ (자동 생성)
delegate.sh가 역할별 agent 로그를 `log/role-N.log`에 저장.

### log-viewer.js (자동 복사)
job-init.sh가 job 디렉토리 생성 시 자동 복사. delegate.sh가 자동 실행하여 브라우저에서 역할별 로그를 실시간 확인.
브라우저 탭 닫으면 하트비트 타임아웃으로 서버 자동 종료.

수동 실행: `node .agent/job-{n}/log-viewer.js [port]`

### .done (자동 생성/삭제)
delegate.sh 완료 시 job 폴더에 생성. 내용: `total=N completed=N failed=N`
메인이 읽은 후 삭제하여 다음 라운드에 대비.
