---
name: cron-job-verify
description: webhook DLQ + cron job 작동 영역 검증 — gh run list + az containerapp logs show + sensor 일괄. 운영 영역 박제 영역 박제.
allowed-tools: Bash
disable-model-invocation: true
trigger-mode: manual
effort: low
owner-agent: grimoire-infrastructure
owner-skill: ""
responsibility-note: "운영 cron job 작동 영역 영역 검증 표준 절차 박제 — PAY-P0-2 PG↔DB 정합성 cron + DLQ 영역 정합"
---

# Cron Job Verify — 운영 cron job 작동 영역 검증

## 책임 영역 (2026-05-10 Phase 2 박제)

- **owner**: grimoire-infrastructure (Azure / Container Apps / cron 영역)
- **trigger 패턴**: `disable-model-invocation: true` — 사용자 명시 호출만
- **사용자 명시 키워드**: "cron 영역 검증" / "DLQ 영역 검증" / "webhook 영역 검증"

> **근거**: PAY-P0-2 PG↔DB 정합성 cron (server `8e9e02e`) + 운영 영역 webhook DLQ 영역 정합 영역 박제. 메인 영역 매번 명령 영역 영역 X = skill 영역 박제 영역.

## 전제 권한 영역 (사용자 직접 영역 강제)

본 skill은 sandbox `Bash(az containerapp logs show:*)` + `Bash(gh run:*)` 영역 권한 영역 추가 영역 필요. 사용자 명시 후 사용자 직접 settings.json 갱신 영역 진입.

## 사용 패턴

### 1. webhook DLQ 영역 검증

```bash
# webhook DLQ 영역 영역 (server 영역 logs 영역 grep)
az containerapp logs show \
  -n grimoire-server-dev -g zenith-rg \
  --tail 100 \
  --type console \
  | grep -E "DLQ|webhook.*failed|paymentReconcile.*failed"
```

### 2. cron job 영역 logs 영역

```bash
# cron 영역 작동 영역 logs (PAY-P0-2 paymentReconcileCron 영역)
az containerapp logs show \
  -n grimoire-server-dev -g zenith-rg \
  --tail 200 \
  --type console \
  | grep -E "PaymentReconcileCron|reconcile.*started|reconcile.*completed"
```

### 3. GitHub Actions 영역 검증 (활성 영역만)

```bash
# 3 레포 영역 GitHub Actions 영역 (5/8 INFRA-1 회복 정합 영역 비활성 박제)
gh run list -R JunYoungJee/grimoire-server --limit 5
gh run list -R JunYoungJee/grimoire-web --limit 5
```

**5/8 INFRA-1 정합 영역**: server / web 영역 GitHub Actions workflow 영역 비활성 박제 (자동 배포 트리거 위반 사고 영역 회복 정합) → "No runs found" 영역 정합 박제 정합.

### 4. sensor 영역 (cron 영역 회귀 영역 검증)

```bash
# webhook 영역 정합 sensor (영역 박제 영역)
ls /Users/sokol/Git/ProjectGrimoire/.claude/scripts/ \
  | grep -E "sensor.*webhook|sensor.*cron|sensor.*dlq"
```

## 사후 박제 영역

```bash
# 결과 영역 박제 (운영 영역 박제 영역)
echo "=== cron-job-verify 결과 ==="
echo "DLQ 영역 건수: N"
echo "PaymentReconcileCron 영역 마지막 작동: <timestamp>"
echo "GitHub Actions 영역 (server/web): No runs found / N runs"
echo "sensor 영역: N건 활성"
```

## 박제 의무 (Mitchell Ghostty 정합)

검증 영역 진행 중 발견하는 결함 / 우회 / 거짓 보고 영역 즉시 박제:

```bash
bash /Users/sokol/Git/ProjectGrimoire/.claude/scripts/incident-log.sh \
  cron_job_verify {severity} {source} "{description}"
```

## 관련 정본
- `grimoire-server/src/payments/cron/payment-reconcile.cron.ts` — PAY-P0-2 cron 영역
- `grimoire-server/src/payments/queue/webhook-dlq.service.ts` — webhook DLQ 영역
- `.claude/agents/grimoire-infrastructure.md` — 책임 agent 자기 정의
- `memory/project_session_20260503_2.md` — PAY-P0-2 박제 영역

## 변경 이력
- 2026-05-10 #10_8 Phase 2: 신설 — 사용자 명시 (5/10) "다 진행해" + Phase 2 8건 skill 영역 6번째. PAY-P0-2 PG↔DB 정합성 cron + 운영 영역 webhook DLQ 영역 정합 영역 박제. 메인 영역 매번 az containerapp logs show + gh run list 영역 영역 X = skill 영역 박제 영역 영역.
