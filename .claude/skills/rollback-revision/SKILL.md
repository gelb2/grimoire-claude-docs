---
name: rollback-revision
description: Container Apps revision activate/deactivate 자동화. dev/prod 사고 회복 시 손으로 명령 박제 부담 해소. 사용자 명시 호출 강제 (destructive infra). 2026-05-06 dev API down 사고 회복 절차 박제.
allowed-tools: Read, Bash, Grep
disable-model-invocation: true
effort: medium
trigger-mode: user-invocation (disable-model-invocation:true)
triggers:
  - "rollback revision"
  - "revision rollback"
  - "이전 revision"
  - "revision 회복"
  - "이전으로 돌려"
  - "rollback"
---

# Rollback-Revision — Container Apps revision 회복 절차

> **trigger-mode**: user-invocation (`disable-model-invocation: true`).
> **신설**: 2026-05-06 묶음 LL — HANDOVER §3 결함 (rollback skill 미존재) 보강.
> **출처**: HANDOVER-CRITICAL-2026-05-06.md §4-2 + §3

## CRITICAL_CONSTRAINTS

- **[MUST]** 사용자 명시 후 진행 (destructive infra change)
- **[MUST]** rollback 직전 현재 revision health snapshot 박제
- **[MUST]** rollback 직후 health 재검증 (3회 polling)
- **[MUST NOT]** prod 영향 시 사용자 명시 없이 진행
- **[MUST NOT]** 138 같은 Deprovisioning revision으로 rollback (전제 약함)

## 절차

### Step 1 — 현 상태 확인 (사용자 명시 받기)

```bash
az containerapp revision list -n {APP_NAME} -g zenith-rg \
  --query "[].{name:name, active:properties.active, traffic:properties.trafficWeight, health:properties.healthState, running:properties.runningState, created:properties.createdTime}" \
  -o table
```

→ Healthy인 이전 revision 존재 여부 확인. 없으면 다른 회복 경로 (새 image rebuild 등).

### Step 2 — rollback 명령 (사용자 명시 후)

```bash
# 이전 revision 활성화
az containerapp revision activate -n {APP_NAME} -g zenith-rg \
  --revision {PREV_REVISION_NAME}

# 트래픽 100% 이전 revision으로
az containerapp ingress traffic set -n {APP_NAME} -g zenith-rg \
  --revision-weight {PREV_REVISION_NAME}=100 {CURRENT_REVISION_NAME}=0
```

### Step 3 — rollback 후 검증 (3회 polling)

```bash
for delay in 30 300 900; do
  sleep $delay
  echo "=== ${delay}s 후 ==="
  az containerapp revision list -n {APP_NAME} -g zenith-rg \
    --query "[?properties.active==true].{name:name, health:properties.healthState, traffic:properties.trafficWeight}"

  /usr/bin/curl --max-time 30 -sI -w "HTTP=%{http_code} TIME=%{time_total}s\n" \
    https://{ENV_DOMAIN}/api/health
done
```

### Step 4 — 박제

```bash
bash .claude/scripts/incident-log.sh infra info self \
  "Rollback {APP_NAME}: {CURRENT_REVISION} → {PREV_REVISION}, health=Healthy 회복" \
  "post-mortem: 원인 root cause 추적 후속"
```

## 관련 정본
- `.claude/skills/infra-mutation-guard/SKILL.md` (변경 직전 절차)
- `reports/HANDOVER-CRITICAL-2026-05-06.md` §4 (다음 세션 즉시 진단 경로)
- `.claude/state/incident-log.jsonl` (사고 박제)

---

마지막 업데이트: 2026-05-06 묶음 LL
