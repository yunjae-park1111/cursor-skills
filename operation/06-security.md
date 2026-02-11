# 6. 보안 및 접근 제어

## 개요

시크릿 관리, 접근 제어, 이미지 보안 스캔 등 보안 관련 정책과 운영 방법을 정의한다.

---

## 시크릿 및 설정 관리

### 1. 관리 정보

- **관리 위치**: `thakicloud/tkai-deploy` 레포지토리의 `helm/secrets, helm/kyverno` 차트
- **저장 방식**: Kubernetes Secret
- **로테이션**: 필요 시 수동 업데이트

### 2. SOPS + Age 기반 암호화

- 시크릿 값은 Age 공개키로 암호화되어 Git에 저장
- ArgoCD 서버에 Age 개인키가 등록되어 있어 배포 시 자동 복호화

**로컬에서 편집**:

1. `helm/secrets/values.yaml` 파일 수정
2. 환경변수 설정:
    ```bash
    export SOPS_AGE_KEY_FILE=~/.sops/age-key.txt
    ```
3. 복호화 → 편집 → 암호화:
    ```bash
    sops -d -i values.yaml  # 복호화
    # 편집
    sops -e -i values.yaml  # 암호화
    ```

**설정 파일 관리**: 레포지토리 루트에 `.sops.yaml`로 설정

```yaml
creation_rules:
  - path_regex: helm/secrets/values\.yaml$
    encrypted_regex: "^(data)$"
    age: age1xxx...  # grep "public key" ~/.sops/age-key.txt 로 확인
```

**Pre-Commit 적용**:

- 비암호화 커밋시, 자동 암호화
- 암호화 파일에 평문 값 추가시, 검증 실패로 커밋 불가

### 3. Kyverno 기반 네임스페이스 간 시크릿 동기화

- 중앙 시크릿 네임스페이스(`tkai-secret`)에 원본 시크릿 저장
- 복제 기준: 원본 시크릿에 `kyverno.io/sync: "true"` 어노테이션이 있고, Pod가 해당 시크릿을 참조하는 경우, Pod의 네임스페이스에 시크릿 여부 확인 후 복제
- 시크릿 삭제 이벤트 시, 시크릿을 참조하는 파드가 있으면 자동 재생성
- 시크릿 참조 Pod가 없으면 1분 내로 삭제

---

## 접근 제어

- RBAC 기반 최소 권한 원칙

---

## 이미지 보안 스캔

- SBOM 적용
- Critical/High 등급에 따른 차단 정책 필요
