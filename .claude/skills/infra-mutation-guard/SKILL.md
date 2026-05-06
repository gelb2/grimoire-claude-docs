---
name: infra-mutation-guard
description: az / polar / 인프라 변경 명령 (containerapp update / set-env-vars / secret set / revision activate-deactivate) 발동 직전 자동 health snapshot + 변경 후 검증 + 실패 시 자동 rollback 가이드. 2026-05-06 dev API down 사고 (revision 153 Unhealthy) 후속 보강. 사용자 명시 호출 강제.
allowed-tools: Read, Bash, Grep
disable-model-invocation: true
effort: high
trigger-mode: user-invocation (disable-model-invocation:true) + 키워드 매칭 (인프라 명령 직전)
triggers:
  - "az containerapp update"
  - "az containerapp set-env-vars"
  - "az containerapp secret set"
  - "az containerapp revision activate"
  - "polar product create"
  - "polar webhook update"
  - "infra-mutation"
  - "인프라 변경"
  - "인프라 바꿔"
  - "환경변수 추가"
  - "배포 직전"
---

# Infra-Mutation-Guard — 인프라 변경 안전망

> **trigger-mode**: user-invocation (`disable-model-invocation: true`) + 키워드 매칭.
> **신설**: 2026-05-06 묶음 LL — dev API revision 153 Unhealthy 사고 + 다른 리모트 8건 시크릿 마이그레이션이 레드팀 자동 검증 0건으로 진행된 결함 보강.
> **출처**: HARNESS_AUDIT_20260504.md §결함 #4 + HANDOVER-CRITICAL-2026-05-06.md §3 + book-completion §17 (Cuneiform Chat 정합)

## CRITICAL_CONSTRAINTS

- **[MUST]** 인프라 변경 명령 직전 자동 health snapshot 박제 (변경 전 상태 = 회복 기준)
- **[MUST]** 변경 후 health 재확인 (변경 직후 30초 + 5분 + 15분 = 3회 polling)
- **[MUST]** revision Unhealthy 검출 시 즉시 rollback 가이드 출력 (사용자 명시 후 진행)
- **[MUST NOT]** sensor-adversarial-pre-commit 통과만으로 "인프라 변경 안전" 단정 (git commit 영역만 검증)
- **[MUST NOT]** 변경 후 health 검증 없이 다음 명령 진행

## 동기 (사고 회고)

**2026-05-06 dev API down 사고** 패턴:
1. PAY-P2 트랙 11 commit + 8건 시크릿 마이그레이션 (`migrate-env-to-secretref.sh`) 진행
2. 매 sprint sensor-adversarial 19P 통과 → "검증 완료" 보고
3. 그러나 `az containerapp update`는 git commit 아니라 **레드팀 sensor 발동 0건**
4. revision 153 Unhealthy 발견을 사후에야 함 (사용자 영역에 떠넘김)
5. 다른 리모트 §3에서 핵심 결함으로 박제

= **레드팀이 git/code 영역만 검증, 인프라 변경 영역 무방비**.

## 4 단계 절차

### Step 1 — 변경 전 health snapshot (자동)

```bash
# Container Apps revision 상태 박제
az containerapp revision list -n {APP_NAME} -g zenith-rg \
  --query "[].{name:name, active:properties.active, traffic:properties.trafficWeight, health:properties.healthState, running:properties.runningState}" \
  -o json > .claude/state/infra-snapshot-{TIMESTAMP}-pre.json

# 현재 활성 revision env (시크릿 변경 시 핵심)
az containerapp show -n {APP_NAME} -g zenith-rg \
  --query "properties.template.containers[0].env" -o json > .claude/state/infra-env-{TIMESTAMP}-pre.json
```

→ 사용자 명시 권한 받아야 실행 (Production Reads 가드).

### Step 2 — 변경 진행 (사용자 명시 후)

```bash
# 예: 시크릿 마이그레이션
bash scripts/security/migrate-env-to-secretref.sh dev {SECRET_NAME}

# 예: 새 image deploy
az containerapp update -n {APP_NAME} -g zenith-rg --image {IMAGE_TAG}
```

### Step 3 — 변경 후 health 검증 (3회 polling)

```bash
# 변경 직후 (30초 후, 5분, 15분)
for delay in 30 300 900; do
  sleep $delay
  az containerapp revision list -n {APP_NAME} -g zenith-rg \
    --query "[?properties.active==true].{name:name, health:properties.healthState, running:properties.runningState}"

  # API 직접 응답 검증 (cold start vs Failed 구분)
  /usr/bin/curl --max-time 30 -sI -w "HTTP=%{http_code} TIME=%{time_total}s\n" \
    https://{ENV_DOMAIN}/api/health
done
```

### Step 4 — Unhealthy 검출 시 rollback 가이드

```bash
# 이전 revision 활성화
az containerapp revision activate -n {APP_NAME} -g zenith-rg \
  --revision {PREV_REVISION_NAME}

# 트래픽 100% 이전 revision으로
az containerapp ingress traffic set -n {APP_NAME} -g zenith-rg \
  --revision-weight {PREV_REVISION_NAME}=100
```

→ rollback도 사용자 명시 후 진행 (destructive infra change).

## 절대 금지 사항

### [MUST NOT] sensor-adversarial 통과만으로 인프라 변경 안전 단정
git/code 영역만 검증. 인프라 영역은 별개.

### [MUST NOT] revision Unhealthy 발견 후 cold start 단정
직접 명령 (revision health + curl 응답) 출력 박제 후 결정.

### [MUST NOT] 변경 후 health 검증 없이 다음 명령 진행
3회 polling (30초/5분/15분) 강제.

### [MUST NOT] dev에서 검증 안 된 마이그레이션 prod 진입
dev 24h 안정성 박제 후 사용자 명시 시만.

## 발동 조건

다음 중 1개 이상:
1. **사용자 명시 호출**: `/infra-mutation-guard <영역>`
2. **트리거 키워드 매칭** (위 frontmatter)
3. **az containerapp / polar 명령 직전** (PreToolUse hook 가능, P2 후속)

## 관련 정본
- `reports/HANDOVER-CRITICAL-2026-05-06.md` §3 (8건 갭 매트릭스)
- `.claude/knowledge/red-team-constitution.md` P13 (시크릿 평문 금지)
- `.claude/state/incident-log.jsonl` (인프라 사고 박제)
- 책 V1.1 Ch 17 보안 5계층 + Ch 18 비용 절감

---

마지막 업데이트: 2026-05-06 묶음 LL
신설 사유: dev API down 사고 + 인프라 영역 무방비 결함 보강 (사용자 명시 후속)
