---
name: deploy-image-verify
description: server/web prod Container App 현재 image SHA vs git main HEAD SHA 정합 검증 절차. sensor-deploy-drift가 권한 차단으로 자동 측정 불가한 영역(운영 image SHA)을 사용자 직접 명령으로 보완. 사용자 명시 호출만 (`/deploy-image-verify [server | web | both]`). HARNESS §10 Phase 4 — 배포 sync 강화.
argument-hint: "[선택: server | web | both] (기본 both)"
disable-model-invocation: true
allowed-tools: Read, Bash, Grep
effort: low
paths:
  - "grimoire-server/Dockerfile"
  - "grimoire-server/scripts/deploy-*.sh"
  - "grimoire-web/Dockerfile"
  - "**/azure*.yaml"
---

# Deploy Image Verify — Container App image SHA 정합 검증

## 동기 (HARNESS §10 Phase 4)

`sensor-deploy-drift.sh`는 다음을 자동 측정:
- ✅ git develop ↔ origin/develop ↔ main 정합
- ✅ dev/prod health endpoint curl
- ❌ **운영 Container App 현재 image SHA vs git main HEAD SHA 비교** ← 권한 차단

본 skill은 마지막 항목을 사용자 직접 명령으로 보완. **메인 Claude는 az 명령 차단** + 사용자만 실행 가능.

## 동작 원리

1. server/web 각 레포의 현재 git main HEAD SHA 추출
2. 사용자에게 az 명령 안내 (Container App image tag 조회)
3. 결과를 메인 Claude에게 paste → image tag의 `prod-{SHA}` 부분과 git main SHA 비교
4. 일치 → PASS / 불일치 → 배포 누락 또는 rollback 필요

## 절차

### Step 1. 모드 결정

```bash
TARGET="${ARGUMENTS:-both}"
case "$TARGET" in
  server|web|both) ;;
  *) echo "Usage: /deploy-image-verify [server | web | both]"; exit 1 ;;
esac
```

### Step 2. git main HEAD SHA 추출 (자동)

```bash
SERVER_SHA=$(cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server && git rev-parse main)
WEB_SHA=$(cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web && git rev-parse main)
echo "[git] server main HEAD: $SERVER_SHA"
echo "[git] web main HEAD: $WEB_SHA"
```

### Step 3. 사용자 직접 az 명령 안내 (메인은 실행 차단)

```
다음 명령을 사용자 터미널에서 직접 실행하시고 결과를 공유해주세요:

# server
az containerapp show \
  --name grimoire-server-prod \
  --resource-group zenith-rg \
  --query properties.template.containers[0].image \
  -o tsv

# web
az containerapp show \
  --name grimoire-web-prod \
  --resource-group zenith-rg \
  --query properties.template.containers[0].image \
  -o tsv

예상 출력 형식:
  grimoireacr.azurecr.io/grimoire-server:prod-{SHA}
  grimoireacr.azurecr.io/grimoire-web:prod-{SHA}
```

### Step 4. SHA 비교 (메인이 받은 결과 처리)

사용자가 제공한 image tag에서 `prod-{SHA}` 추출 → git main HEAD와 비교:

```python
# 메인이 사용자 응답 받은 후 처리
container_image = "grimoireacr.azurecr.io/grimoire-server:prod-e8e34ab062f4..."
container_sha = container_image.split(":prod-")[1] if ":prod-" in container_image else None
git_sha = "e8e34ab062f41231b21f0c7487a3968451620fc7"  # git rev-parse main 결과

if container_sha and git_sha.startswith(container_sha[:12]):
    print(f"[PASS] server image SHA 일치 ({container_sha[:12]})")
else:
    print(f"[FAIL] server image SHA 불일치")
    print(f"  Container: {container_sha[:12]}")
    print(f"  git main:  {git_sha[:12]}")
    print(f"  → 배포 누락 또는 rollback 필요")
```

### Step 5. 결과 박제

`.claude/state/deploy-image-verify.jsonl` 적재:

```json
{
  "ts": "2026-04-27T03:40:59Z",
  "server_git_sha": "e8e34ab",
  "server_image_sha": "e8e34ab",
  "server_match": true,
  "web_git_sha": "bab239b",
  "web_image_sha": "bab239b",
  "web_match": true,
  "status": "PASS"
}
```

## 절대 금지 사항

### [MUST NOT] 메인 Claude가 az 명령 직접 실행
- az containerapp 호출은 운영 Azure API → 권한 차단됨
- 사용자 직접 실행만 허용

### [MUST NoT] image tag 직접 편집
- 본 skill은 verify 전담 — 불일치 발견 시 사용자에게 보고만
- 재배포는 `/deploy-precheck` 또는 직접 `make deploy-prod`로 진행

### [MUST NOT] 환경 혼동
- server/web prod만 검증 대상 (`grimoire-server-prod`, `grimoire-web-prod`)
- dev 환경은 자동 배포 미연동이라 별도 절차

## 적용 사례

### 정상 사례 (2026-04-27 #9 W 배포)
- server git main: `e8e34ab062f41231b21f0c7487a3968451620fc7`
- server image: `prod-e8e34ab062f41231b21f0c7487a3968451620fc7`
- → PASS (일치)

### 비정상 사례 (가설)
- server git main: `latest_commit_sha`
- server image: `prod-old_commit_sha` (배포 누락)
- → FAIL → `make deploy-prod` 재실행 필요

## 권장 빈도

- **prod 배포 직후**: 1회 (배포 성공 확인)
- **주 1회**: drift 누락 사후 점검
- **장애 발생 시**: 즉시 (운영 image와 git main 정합성 우선 검증)

## 관련 정본

- `.claude/scripts/sensor-deploy-drift.sh` — 자동 측정 영역 (image SHA 외)
- `.claude/skills/deploy-precheck/SKILL.md` — 배포 직전 게이트
- `grimoire-server/scripts/deploy-prod.sh` — image tag 형식 정의 (`prod-{SHA}`)
- `research/HARNESS_ENGINEERING.md` §10 Phase 4 — 배포 동기화 강화

---

마지막 업데이트: 2026-04-27
승격 원본: HARNESS §10 Phase 4 (운영 image 검증)
적용 영역: ProjectGrimoire prod (Container Apps)
