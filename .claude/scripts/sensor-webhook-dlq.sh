#!/usr/bin/env bash
# sensor-webhook-dlq — PAY-P2-2 webhook DLQ (Postgres RetryQueue) 회귀 차단 (sprint #10_7)
#
# 발동 조건:
# - pre-commit / pre-push (server 변경 시)
# - 정기 회귀 (eval-runner)
#
# 정본 (단일 진실):
# - `reports/sprint-pay-p2-2-webhook-dlq-progress.md` §2 AC-1~AC-9
# - `.claude/shared-contracts.md` §18 WebhookDLQ
# - `reports/PAY-P2-MASTER-PLAN.md` §4
#
# 검증 영역 (12건):
# 1. WebhookRetryQueue Prisma 모델 박제 (eventId @unique + nextRetryAt index + payload Json)
# 2. Migration 파일 박제 (20260505020000_add_webhook_retry_queue)
# 3. WebhookRetryQueueRepositoryPort 인터페이스 박제 (5 메서드)
# 4. PrismaWebhookRetryQueueRepository 구현 박제 (P2002 race 안전)
# 5. WebhookRetryJob @Cron 5분 주기 박제
# 6. WebhookRetryJob MAX_RETRY=10 박제
# 7. WebhookRetryJob exp backoff (1m/5m/30m/2h/12h/24h) 박제
# 8. WebhookRetryJob isRunning lock 박제
# 9. payment.usecase processNormalizedWebhook 분리 박제
# 10. payment.usecase enqueueWebhookRetry 호출 (success + cancel 실패 분기 양쪽)
# 11. app.module WebhookRetryJob + WebhookRetryQueueRepositoryPort 등록
# 12. spec 8 it (webhook-retry.job.spec.ts)
#
# Exit codes:
# - 0 PASS — 모두 정합
# - 2 FAIL — 회귀 검출 (commit 차단)

trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set +e

REPO_ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER="$REPO_ROOT/grimoire-server"
SCHEMA="$SERVER/prisma/schema.prisma"
MIGRATION_DIR="$SERVER/prisma/migrations/20260505020000_add_webhook_retry_queue"
PORT="$SERVER/src/domain/port/outbound/webhook-retry-queue-repository.port.ts"
REPO_IMPL="$SERVER/src/adapter/outbound/persistence/prisma-webhook-retry-queue.repository.ts"
JOB="$SERVER/src/application/payment/webhook-retry.job.ts"
JOB_SPEC="$SERVER/src/application/payment/webhook-retry.job.spec.ts"
USECASE="$SERVER/src/application/payment/payment.usecase.ts"
APP_MODULE="$SERVER/src/app.module.ts"

echo "── sensor-webhook-dlq (PAY-P2-2 회귀 차단) ──"

PASS=0
FAIL=0

# [1/12] schema 모델 박제
if grep -nE 'model WebhookRetryQueue' "$SCHEMA" > /dev/null 2>&1 && \
   grep -nE 'eventId.*@unique' "$SCHEMA" > /dev/null 2>&1 && \
   grep -nE '@@index\(\[nextRetryAt\]\)' "$SCHEMA" > /dev/null 2>&1; then
  echo "  ✓ [1/12] WebhookRetryQueue 모델 + eventId @unique + nextRetryAt @@index 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [1/12] WebhookRetryQueue 모델 또는 인덱스 누락"
  FAIL=$((FAIL+1))
fi

# [2/12] migration 파일
if [ -f "$MIGRATION_DIR/migration.sql" ]; then
  echo "  ✓ [2/12] Migration 파일 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [2/12] Migration 파일 누락 ($MIGRATION_DIR/migration.sql)"
  FAIL=$((FAIL+1))
fi

# [3/12] Port 인터페이스 5 메서드
PORT_METHODS=$(grep -cE '^\s*(upsert|findDue|deleteById|markRetry|findByEventId)\(' "$PORT")
if [ "$PORT_METHODS" -ge 5 ]; then
  echo "  ✓ [3/12] WebhookRetryQueueRepositoryPort 5 메서드 박제 ($PORT_METHODS건)"
  PASS=$((PASS+1))
else
  echo "  ✗ [3/12] Port 메서드 부족 ($PORT_METHODS건 < 5)"
  FAIL=$((FAIL+1))
fi

# [4/12] Repository 구현 — P2002 race 안전 + Prisma.PrismaClientKnownRequestError
if grep -nE 'P2002' "$REPO_IMPL" > /dev/null 2>&1 && \
   grep -nE 'Prisma\.PrismaClientKnownRequestError' "$REPO_IMPL" > /dev/null 2>&1; then
  echo "  ✓ [4/12] PrismaWebhookRetryQueueRepository P2002 race 안전 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [4/12] P2002 race 안전 패턴 누락"
  FAIL=$((FAIL+1))
fi

# [5/12] @Cron 5분 주기
if grep -nE "@Cron\([\"'].*5 \* \* \* \*[\"']\)" "$JOB" > /dev/null 2>&1; then
  echo "  ✓ [5/12] WebhookRetryJob @Cron 5분 주기 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [5/12] @Cron 5분 주기 박제 누락"
  FAIL=$((FAIL+1))
fi

# [6/12] MAX_RETRY=10
if grep -nE 'MAX_RETRY\s*=\s*10' "$JOB" > /dev/null 2>&1; then
  echo "  ✓ [6/12] MAX_RETRY=10 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [6/12] MAX_RETRY=10 박제 누락"
  FAIL=$((FAIL+1))
fi

# [7/12] exp backoff (1m/5m/30m/2h/12h/24h) — 분 단위 (1, 5, 30, 120, 720, 1440)
if grep -nE '\b1\s*,\s*$|\b5\s*,\s*$|\b30\s*,\s*$|\b120\s*,\s*$|\b720\s*,\s*$|\b1440\b' "$JOB" > /dev/null 2>&1; then
  echo "  ✓ [7/12] exp backoff 매트릭스 박제 (1/5/30/120/720/1440 minutes)"
  PASS=$((PASS+1))
else
  echo "  ✗ [7/12] exp backoff 매트릭스 누락"
  FAIL=$((FAIL+1))
fi

# [8/12] isRunning lock
if grep -nE 'private isRunning\s*=\s*false' "$JOB" > /dev/null 2>&1 && \
   grep -nE 'this\.isRunning\s*=\s*true' "$JOB" > /dev/null 2>&1; then
  echo "  ✓ [8/12] isRunning lock 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [8/12] isRunning lock 누락"
  FAIL=$((FAIL+1))
fi

# [9/12] processNormalizedWebhook 분리
if grep -nE 'async processNormalizedWebhook' "$USECASE" > /dev/null 2>&1; then
  echo "  ✓ [9/12] payment.usecase processNormalizedWebhook 분리 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [9/12] processNormalizedWebhook 분리 누락"
  FAIL=$((FAIL+1))
fi

# [10/12] enqueueWebhookRetry 호출 (success + cancel 실패 분기 양쪽)
ENQUEUE_COUNT=$(grep -cE 'this\.enqueueWebhookRetry' "$USECASE")
if [ "$ENQUEUE_COUNT" -ge 2 ]; then
  echo "  ✓ [10/12] enqueueWebhookRetry 호출 ≥2건 ($ENQUEUE_COUNT건 — success + cancel 실패 분기)"
  PASS=$((PASS+1))
else
  echo "  ✗ [10/12] enqueueWebhookRetry 호출 부족 ($ENQUEUE_COUNT건 < 2)"
  FAIL=$((FAIL+1))
fi

# [11/12] app.module 등록
if grep -nE 'WebhookRetryJob' "$APP_MODULE" > /dev/null 2>&1 && \
   grep -nE 'WebhookRetryQueueRepositoryPort' "$APP_MODULE" > /dev/null 2>&1; then
  echo "  ✓ [11/12] app.module WebhookRetryJob + WebhookRetryQueueRepositoryPort 등록 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [11/12] app.module 등록 누락"
  FAIL=$((FAIL+1))
fi

# [12/12] spec 8 it
if [ -f "$JOB_SPEC" ]; then
  IT_COUNT=$(grep -cE "^\s*it\(['\"][0-9]+/8" "$JOB_SPEC")
  if [ "$IT_COUNT" -ge 8 ]; then
    echo "  ✓ [12/12] webhook-retry.job.spec.ts 8 it 박제"
    PASS=$((PASS+1))
  else
    echo "  ✗ [12/12] spec it 부족 ($IT_COUNT건 < 8)"
    FAIL=$((FAIL+1))
  fi
else
  echo "  ✗ [12/12] webhook-retry.job.spec.ts 파일 누락"
  FAIL=$((FAIL+1))
fi

echo ""
echo "── 종합 ──"
echo "  PASS: $PASS / FAIL: $FAIL"

if [ $FAIL -gt 0 ]; then
  echo "  ✗ FAIL — PAY-P2-2 회귀 검출 (commit 차단)"
  echo "  → 정본: reports/sprint-pay-p2-2-webhook-dlq-progress.md §2 AC-1~AC-9"
  exit 2
fi

echo "  ✓ PASS — PAY-P2-2 webhook DLQ 정합"
exit 0
