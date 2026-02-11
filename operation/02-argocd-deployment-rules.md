# 2. ArgoCD 배포 규칙

## 개요

배포 차트의 규칙에 따라 ArgoCD에서 공통 설정을 적용하고, 환경별 설정을 관리하는 규칙을 정의한다.

---

## 2.1 Helm 차트 규칙

**차트 규칙**:

- Helm 차트에 `global.image.tag` 필수 추가
- `global.image.override: true` → `global.image.tag` 우선
- `global.image.override: false` → 각 서비스별 이미지 태그 우선

**서브 이미지 규칙**:

Helm 차트에서 Job, CronJob 등으로 별도 컨테이너 이미지를 사용하는 경우:

- 차트 규칙: `global.subimage.{name}.name, global.subimage.{name}.tag` 형식으로 정의
- 적용 대상: 차트로 배포되는 이미지 외 관리되어야 하는 이미지
- 예시:
    - `global.subimage.workload.name: "ghcr.io/thakicloud/ai-platform-workload"`
    - `global.subimage.workload.tag: "v0.7.0"`

**HTTPRoute 규칙:**

Helm 차트에서 HTTPRoute를 추가하는 경우:

- 차트 Value Root에 `httproute` 필드 정의
- 상세 내용 참조: [HTTPRoute 템플릿 가이드](https://www.notion.so/HTTPRoute-2cd9eddc34e68005bae3e2e2074e8399)

## 2.2 ArgoCD 파라미터 규칙

ArgoCD Application의 `values-{env}.yaml`에서 이미지 버전을 설정할 때의 규칙입니다.

- 설정 위치: `thakiCloud/tkai-deploy` 레포의 `argo-apps/charts/argo-applications/values-{env}.yaml`

### 메인 이미지

- 각 Application에 `image.tag`가 있으면 → 해당 값을 `global.image.tag` 파라미터로 전달
- 각 Application에 `image.tag`가 없으면 → global 설정을 따름
- 둘 중 하나라도 설정되어 있으면 → `global.image.override: true` 파라미터 추가

### 서브 이미지

- 각 Application에 `subimage.{name}.name`가 있으면 해당 값을 `global.subimage.{name}.name` 파라미터로 전달
- 각 Application에 `subimage.{name}.tag`가 있으면 해당 값을 `global.subimage.{name}.tag` 파라미터로 전달
    - `subimage.{name}.name`이 있을 때, `subimage.{name}.tag` 값이 없을 시 에러
- 예시:
    - `app.subimage.workload.name: "ghcr.io/thakicloud/ai-platform-workload"` → `global.subimage.workload.name: "ghcr.io/thakicloud/ai-platform-workload"`
    - `app.subimage.workload.tag: "v0.7.0"` → `global.subimage.workload.tag: "v0.7.0"`

### HTTPRoute

- 각 Application의 Helm 파라미터에 `httproute.hostnames[N]` 형식으로 정의
- `global.domain`에 값이 존재하며, 각 Application의 `domainPrefix` 지정 시, `global.domain`에 해당 `domainPrefix`를 subdomain으로 하여 자동 추가
- 예시:
    - `global.domain: tkai.thakicloud.site`
    - `app.domainPrefix: test`
        - `test.tkai.thakicloud.site`로 자동 추가
    - 사용자 정의 파라미터 추가
        - `name: httproute.hostname[0]`
        - `value: tkai.thakicloud.site`
