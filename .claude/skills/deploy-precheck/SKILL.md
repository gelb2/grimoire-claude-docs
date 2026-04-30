---
name: deploy-precheck
description: 수동 배포(make deploy-{dev,prod}) 직전 정합성 종합 검증. server/web 양 레포 git 상태 + 브랜치 정합성 + sensor-secret-leak + 양 레포 docs 동기화 + Container Apps 상태 sanity. GitHub Actions 미사용 환경에서 manual deploy 게이트.
argument-hint: "[배포 대상 환경: dev | prod] (기본 dev)"
disable-model-invocation: true
allowed-tools: Read, Bash, Grep, Glob
effort: medium
paths:
  - "grimoire-server/Dockerfile"
  - "grimoire-server/Makefile"
  - "grimoire-web/Dockerfile"
  - "grimoire-web/Makefile"
  - "**/scripts/deploy-*.sh"
---

> **2026-04-25 세션 #7**: `.claude/commands/deploy-precheck.md`에서 마이그레이션. `disable-model-invocation: true`로 사용자 명시 호출만 허용 (`/deploy-precheck`).

# Deploy Precheck — 수동 배포 직전 정합성 게이트

당신은 ProjectGrimoire의 배포 게이트키퍼입니다. 본 슬래시 커맨드는 GitHub Actions 미사용 환경(수동 배포 1차 정책)에서 `make deploy-{env}` 직전 회귀 차단을 강제합니다.

## 입력
- `$ARGUMENTS`: `dev` 또는 `prod` (기본 `dev`)

## 절차 (모두 실측 기반, 추정 금지)

### Step 1. 환경·도구 sanity

```bash
ENV="${ARGUMENTS:-dev}"
case "$ENV" in dev|prod) ;; *) echo "ENV must be dev|prod"; exit 1 ;; esac

echo "=== sanity ==="
which az node npm docker | head -5
az account show --query "user.name" -o tsv 2>&1 | head -1  # rainmaker8492@gmail.com 기대
node --version; npm --version
docker info 2>&1 | grep -E "Server Version|ID:" | head -2
```

판정: az login 만료 시 즉시 중단 → `az login` 후 재시도

### Step 2. 양 레포 git 정합성

```bash
for REPO in /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web; do
  echo "=== $REPO ==="
  cd "$REPO"
  echo "branch: $(git rev-parse --abbrev-ref HEAD)"
  echo "status:"
  git status -s
  echo "ahead/behind origin:"
  git fetch origin --quiet
  case "$ENV" in
    dev) BRANCH=develop ;;
    prod) BRANCH=main ;;
  esac
  git rev-list --left-right --count HEAD...origin/$BRANCH
done
```

판정:
- 작업 트리 dirty → 중단 (커밋 또는 stash)
- 현재 브랜치 ≠ 배포 대상 브랜치 → 중단 (`git checkout`)
- ahead != 0 → push 안 됐음 (배포 후 origin과 차이 발생 가능)
- behind != 0 → 최신 아님 (git pull 후 재시도)

### Step 3. 시크릿 누출 검사 (sensor-secret-leak.sh)

```bash
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-secret-leak.sh
EXIT=$?
case $EXIT in
  0) echo "✅ secret-leak PASS" ;;
  2) echo "⚠️ secret-leak WARN (의도된 vault만 매칭)" ;;
  1) echo "❌ secret-leak FAIL — 배포 차단"; exit 1 ;;
esac
```

판정: FAIL 시 즉시 중단. 배포 전 평문 회수 필수.

### Step 4. docs 동기화 검증 (server ↔ web 9종)

```bash
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-docs-sync.sh
```

판정: FAIL 시 정본 문서 복사 후 재시도

### Step 5. server 또는 web 빌드 sanity (대상 레포만)

server 배포면:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
npx tsc --noEmit && npm test && npm run build
```

web 배포면:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web
npx tsc --noEmit && npm test -- --run && npm run build
```

판정: tsc/test/build 중 하나라도 실패 → 중단

### Step 6. Container Apps 현재 상태 sanity (대상 환경만)

```bash
APP="grimoire-server-$ENV"  # 또는 grimoire-web-$ENV
az containerapp show -g zenith-rg -n "$APP" --query "{revision: properties.latestRevisionName, replicas: properties.template.scale, fqdn: properties.configuration.ingress.fqdn}" -o json
```

판정:
- 현재 active revision 존재 확인
- min/max replicas 정책 확인 (cost 절감용 min=0 정상)
- fqdn 응답 정상

### Step 7. preflight 호출 (server 전용 기존 스크립트)

```bash
case "$ENV" in
  dev|prod)
    cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
    bash scripts/preflight.sh "$ENV"
    ;;
esac
```

## 출력 양식 (Verification-before-completion 적용)

```markdown
## Deploy Precheck — ENV: {dev|prod} — YYYY-MM-DD HH:MM

### Step 1. sanity: PASS/FAIL (az user, node, docker)
### Step 2. git 정합성:
  - server: branch={...}, dirty={Y/N}, ahead/behind={...}
  - web:    동일
### Step 3. secret-leak: PASS / WARN / FAIL
### Step 4. docs-sync: PASS / FAIL
### Step 5. build sanity: PASS / FAIL
### Step 6. Container App 상태: 정상/이상
### Step 7. preflight: PASS / FAIL

## 종합 판정
🟢 GO / 🟡 PROCEED WITH CAUTION / 🔴 STOP

## 다음 명령
GO 시:
  cd grimoire-{server|web}
  SKIP_INTERACTIVE=1 make deploy-{env}

STOP 시:
  (각 FAIL 항목별 수정 명령 인라인 제시)
```

## 절대 금지 사항

- **[MUST NOT]** secret-leak FAIL 무시하고 배포 진행
- **[MUST NOT]** dirty working tree 상태 배포 (uncommitted 변경 손실 위험)
- **[MUST NOT]** 잘못된 브랜치(예: feature 브랜치 상태에서 prod 배포) 진행
- **[MUST NOT]** docs 동기화 FAIL 상태 배포 (server/web 정본 불일치)
- **[MUST NOT]** verification-before-completion Skill의 Gate 1·2·3 우회

## 관련 정본

- `grimoire-server/scripts/deploy-common.sh` — 배포 공용 함수
- `grimoire-server/scripts/preflight.sh` — 기존 preflight (이 슬래시는 그 상위 wrapper)
- `.claude/scripts/sensor-security-gate.sh` §9 — secret leak 통합
- `.claude/scripts/sensor-secret-leak.sh` — 본 명령의 핵심 의존
- `.claude/scripts/sensor-docs-sync.sh` — docs 9종 해시 검증
- `feedback_manual_deploy_primary.md` — GitHub Actions 미사용 정책

---

마지막 업데이트: 2026-04-25
