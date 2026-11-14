---
name: dev-health-check
description: Sprint 진입 전 dev 환경 영역 검증 — sensor-deploy-health + sensor-fk-cascade-policy + curl + revision list 일괄. PAY-P3-E §7-1 단계 6-1 영역 정합.
allowed-tools: Bash
disable-model-invocation: true
trigger-mode: manual
effort: low
owner-agent: grimoire-infrastructure
owner-skill: ""
responsibility-note: "Sprint 진입 전 dev 환경 영역 영역 검증 표준 절차 박제 — 5/8 INFRA-1 + PAY-P3-E §7-1 단계 6-1 정합"
---

# Dev Health Check — Sprint 진입 전 dev 환경 영역 검증

## 책임 영역 (2026-05-10 Phase 2 박제)

- **owner**: grimoire-infrastructure (Azure / Container Apps / sensor)
- **trigger 패턴**: `disable-model-invocation: true` — 사용자 명시 호출만
- **사용자 명시 키워드**: "dev 환경 검증" / "Pre-Deploy 영역 검증" / "Sprint 진입 영역 검증"

> **근거**: 5/8 INFRA-1 회복 정합 영역 sensor-deploy-health + sensor-azure-env-secret 영역 박제 + PAY-P3-E §7-1 단계 6-1 (Pre-Deploy revision 158 4 PASS + sensor-fk-cascade-policy 10/10 PASS) 영역 정합.

## 언제 발동하는가

다음 상황 1개 이상:

1. Sprint 진입 영역 진입 시점 (PAY-P3-E 영역 등 server 변경 sprint 영역)
2. dev 환경 영역 회복 영역 검증 진입 시점
3. 사용자 명시 "dev 환경 검증"

## 표준 명령 묶음 (4 단계)

### 단계 1 — sensor-deploy-health 영역 dev 영역

```bash
# 5/5 PASS 영역 임계 영역
bash /Users/sokol/Git/ProjectGrimoire/.claude/scripts/sensor-deploy-health.sh dev
```

**임계 영역**: 5/5 PASS. 1건 이상 FAIL 영역 발견 시 즉시 STOP.

### 단계 2 — sensor-azure-env-secret 영역 dev 영역

```bash
# 환경 변수 + secret 영역 누락 영역 검증
bash /Users/sokol/Git/ProjectGrimoire/.claude/scripts/sensor-azure-env-secret.sh dev
```

**임계 영역**: 누락 0건. 1건 이상 누락 영역 발견 시 즉시 STOP.

### 단계 3 — sensor-fk-cascade-policy 영역 (schema 영역 sprint 영역)

```bash
# schema 영역 sprint 영역 정합 검증 (PAY-P3-E 영역 등)
bash /Users/sokol/Git/ProjectGrimoire/.claude/scripts/sensor-fk-cascade-policy.sh
```

**임계 영역**: 10/10 PASS (33 FK 매트릭스 4 전략 분포 정합).

### 단계 4 — dev curl + revision list 영역

```bash
# dev API 영역 curl 검증 (HTTP 200 + cold start 영역 박제)
curl -sS -w "%{http_code} %{time_total}s\n" \
  https://dev-api.grimoire-book.com/api/payments/products

# dev revision 영역 list (Healthy + Active 박제)
az containerapp revision list \
  -n grimoire-server-dev -g zenith-rg \
  --query "[?properties.active==true].{name:name, healthState:properties.healthState, image:properties.template.containers[0].image}" \
  -o table
```

## 사후 박제 영역

```bash
# 검증 결과 영역 박제 (사용자 보고 영역 또는 reports/INFRA_REPORT.md 영역)
echo "=== dev health check 결과 ===" 
echo "deploy-health: 5/5 PASS"
echo "env-secret: 누락 0건"
echo "fk-cascade-policy: 10/10 PASS"
echo "curl: 200 / N.Ns"
echo "revision: <revision-name> Healthy Active"
```

## sensor 부재 영역 (Phase 2 미신설 영역)

- `sensor-fk-cascade-policy.sh` 영역 — PAY-P3-E §7-1 단계 1~6 영역 신설 정합 (5/10 본 세션 박제 정합)
- 다른 sensor 영역 — `.claude/scripts/sensor-*.sh` 영역 47건 박제 정합 (5/10 종료 인벤토리)

## 박제 의무 (Mitchell Ghostty 정합)

검증 영역 진행 중 발견하는 결함 / 우회 / 거짓 보고 영역 즉시 박제:

```bash
bash /Users/sokol/Git/ProjectGrimoire/.claude/scripts/incident-log.sh \
  dev_health_check {severity} {source} "{description}"
```

## 관련 정본
- `.claude/scripts/sensor-deploy-health.sh` — 5 단계 검증 sensor
- `.claude/scripts/sensor-azure-env-secret.sh` — env+secret 누락 sensor
- `.claude/scripts/sensor-fk-cascade-policy.sh` — schema 영역 정합 sensor
- `.claude/shared-contracts.md` §21 — INFRA-1 인터페이스 정본
- `.claude/agents/grimoire-infrastructure.md` — 책임 agent 자기 정의

## 변경 이력
- 2026-05-10 #10_8 Phase 2: 신설 — 사용자 명시 (5/10) "다 진행해" + Phase 2 8건 skill 영역 4번째. 5/8 INFRA-1 + PAY-P3-E §7-1 단계 6-1 영역 정합 영역 박제. 메인 영역 매번 4 단계 명령 영역 영역 X = skill 영역 박제 영역 영역.
