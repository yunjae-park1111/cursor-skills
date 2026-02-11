# 1. 개요

본 문서는 TKAI 시스템의 배포 자동화, 일상 운영, 장애 대응, 모니터링, 보안 등 전반적인 운영 프로세스를 정의합니다.

- 배포는 ArgoCD를 통해 관리
    - 수정 사항 발생시, ArgoCD에서 해당 앱 Sync 필요
- 환경별 환경변수, 버전 지정 등 ArgoCD에서 관리

## 사전 준비

### 1. SSH 키 생성

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

GitHub에 공개키 등록 필요

### 2. AGE KEY 저장

`~/.sops/age-key.txt` 해당 경로에 저장

- AGE KEY를 새로 생성해야하는 경우:
    ```bash
    brew install age sops && mkdir -p ~/.sops && age-keygen -o ~/.sops/age-key.txt
    ```
    - **기존 AGE KEY를 변경해야 하는 경우에 새로 생성**
- `age-key.txt`는 클러스터 구분없이 통합 암호화 관리 키로 사용 가능

### 3. ArgoCD 설치

- `thakicloud/tkai-deploy` 레포지토리의 `helm/argo` 차트 사용

```bash
helm upgrade --install argocd helm/argo -n argo --create-namespace \
  --set secrets.ageKey="$(cat ~/.sops/age-key.txt)" \
  --set secrets.sshPrivateKey="$(cat ~/.ssh/id_ed25519)"
```
