# TKAI 서버 운영 방안

**작성일**: 2026-02-02

**작성자**: 박윤재

---

## 문서 구성

본 문서는 TKAI 시스템의 배포 자동화, 일상 운영, 장애 대응, 모니터링, 보안 등 전반적인 운영 프로세스를 정의합니다.

| # | 문서 | 설명 |
|---|------|------|
| 1 | [개요](./01-overview.md) | 시스템 개요 및 사전 준비 사항 |
| 2 | [ArgoCD 배포 규칙](./02-argocd-deployment-rules.md) | Helm 차트 규칙, 이미지 규칙, HTTPRoute 규칙, ArgoCD 파라미터 규칙 |
| 3 | [배포 주기 및 프로세스](./03-deployment-cycle.md) | 배포 구분, 파이프라인, 자동화 |
| 4 | [운영 및 장애 대응](./04-operations.md) | 일상 운영, 장애 대응, 백업 및 복구 |
| 5 | [모니터링](./05-monitoring.md) | ArgoCD Dashboard, Git Workflow, Slack 알림 |
| 6 | [보안 및 접근 제어](./06-security.md) | 시크릿 관리, RBAC, 이미지 보안 스캔 |

## 관련 레포지토리

- **배포 관리**: `thakicloud/tkai-deploy`
- **시크릿/설정**: `thakicloud/tkai-deploy` → `helm/secrets`, `helm/kyverno`
