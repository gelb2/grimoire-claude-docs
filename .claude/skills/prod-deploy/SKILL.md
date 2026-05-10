---
name: prod-deploy
description: prod 배포 영역 — Pre-Deploy + sensor-deploy-health + sensor-azure-env-secret + make deploy-prod + 사후 검증 5 Step 강제. 5/8 INFRA-1 사고 영역 회복 정합 영역 박제.
allowed-tools: Bash
disable-model-invocation: true
trigger-mode: manual
effort: high
owner-agent: grimoire-infrastructure
owner-skill: ""
responsibility-note: "prod 배포 표준 절차 박제 — 5/8 INFRA-1 (revision 97 ActivationFailed PUBLIC_API_BASE_URL 누락) 사고 회복 정합"
---

# Prod Deploy — prod 배포 5 Step 강제

## 책임 영역 (2026-05-10 Phase 2 박제)

- **owner**: grimoire-infrastructure (Azure / Container Apps / secret / cron)
- **trigger 패턴**: `disable-model-invocation: true` — 사용자 명시 호출만
- **사용자 명시 키워드**: "prod 배포 진행" / "make deploy-prod" 등

> **근거**: 5/8 INFRA-1 사고 (revision 97 ActivationFailed `PUBLIC_API_BASE_URL` 누락 + 사용자 분노/자해 위협) → INFRA-1 Sprint (sensor-deploy-health + sensor-azure-env-secret + shared-contracts §21 + regression-65) 영역 회복 정합 박제.

## 전제 권한 영역 (사용자 직접 영역 강제)

본 skill은 sandbox `Bash(make deploy-prod:*)` 영역 권한 영역 추가 영역 필요. 사용자 명시 후 사용자 직접 settings.json 갱신 영역 진입.

## 사용자 결정 영역 (5/9 박제)

- main 머지 시점 (3 레포 develop → main per-repo 명시)
- **GitHub Actions workflow 비활성 박제** (5/8 자동 배포 트리거 위반 사고 영역, server `8e8dcfd` + web `e095920`) — 수동 배포만 정합

## 표준 명령 묶음 (5 Step)

### Step 1 — Pre-Deploy 영역 (sensor-azure-env-secret)

```bash
# prod 환경 변수 영역 + secret 누락 영역 검증
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-azure-env-secret.sh prod
```

**임계 영역**: 누락 0건. 1건 이상 누락 영역 발견 시 즉시 STOP.

### Step 2 — Pre-Deploy 영역 (sensor-deploy-health prev revision)

```bash
# 현재 prod revision 영역 health 영역 박제
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-deploy-health.sh prod
```

**임계 영역**: 5/5 PASS. 1건 이상 FAIL 영역 발견 시 즉시 STOP.

### Step 3 — make deploy-prod 영역

```bash
# 3 레포 영역 main 머지 정합 검증 (사용자 명시 후)
cd /Users/sokol/Desktop/Git/ProjectGrimoire
git -C grimoire-server log main --oneline -1
git -C grimoire-web log main --oneline -1

# prod 배포 영역
make deploy-prod
```

**예상 시간 영역**: ~10~15분 (Docker build + push + Azure deploy + revision rollover)

### Step 4 — 사후 검증 영역 (revision Healthy + curl + sensor)

```bash
# revision list 영역 (Healthy 박제)
az containerapp revision list \
  -n grimoire-server-prod -g zenith-rg \
  --query "[].{name:name, healthState:properties.healthState, active:properties.active}" \
  -o table | head -5

# prod curl 영역 (HTTP 200)
curl -sS -w "%{http_code} %{time_total}s\n" \
  https://api.grimoire-book.com/api/payments/products

# sensor-deploy-health 영역 prod 영역 (5/5 PASS)
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-deploy-health.sh prod

# sensor-azure-env-secret 영역 prod 영역
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-azure-env-secret.sh prod
```

**임계 영역**: 모두 PASS. 1건 이상 FAIL 영역 = 즉시 rollback 영역 진입.

### Step 5 — 사후 박제 영역

```bash
# memory/project_session_YYYYMMDD_N.md 영역 갱신
# HANDOVER_NEXT_SESSION.md §1.X 영역 prod 영역 박제
# claude-docs commit + push (grimoire-harness 책임 영역)
```

## rollback 영역 (사고 영역 진입 영역)

```bash
# revision 영역 prev 영역 강제 재배포
az containerapp revision activate \
  -n grimoire-server-prod -g zenith-rg \
  --revision <prev-revision-name>

# revision 영역 latest 영역 비활성
az containerapp revision deactivate \
  -n grimoire-server-prod -g zenith-rg \
  --revision <failed-revision-name>
```

**근거**: 5/8 INFRA-1 사고 영역 = revision 96 강제 재배포 → 98 Healthy 회복.

## 박제 의무 (Mitchell Ghostty 정합)

명령 묶음 영역 진행 중 발견하는 결함 / 우회 / 거짓 보고 영역 즉시 박제:

```bash
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/incident-log.sh \
  prod_deploy {severity} {source} "{description}"
```

## 관련 정본
- `.claude/scripts/sensor-deploy-health.sh` — 사후 검증 sensor
- `.claude/scripts/sensor-azure-env-secret.sh` — Pre-Deploy sensor
- `.claude/shared-contracts.md` §21 — INFRA-1 인터페이스 정본
- `.claude/agents/grimoire-infrastructure.md` — 책임 agent 자기 정의
- `memory/project_session_20260508.md` — 5/8 INFRA-1 사고 박제

## 변경 이력
- 2026-05-10 #10_8 Phase 2: 신설 — 사용자 명시 (5/10) "다 진행해" + Phase 2 8건 skill 영역 2번째. 5/8 INFRA-1 사고 회복 정합 영역 박제. 메인 영역 매번 5 Step 명령 영역 영역 X = skill 영역 박제 영역 영역.
