#!/bin/bash
# sensor-payment-idempotency
# PAY-P0-1: Polar webhook event_id 멱등성 패턴 검증 sensor.
# Constitution P16 (결제 원자성)와 함께 commit 직전 자동 차단.
#
# 검증 대상:
#   1. WebhookEvent Prisma 모델 + @unique eventId
#   2. NormalizedWebhookEvent.eventId 필드
#   3. polar.adapter webhook-id 헤더 추출
#   4. payment.usecase.processWebhook의 findByEventId 게이트
#   5. WebhookEventRepositoryPort 존재
#   6. Prisma 마이그레이션 파일 존재
#
# Exit codes:
#   0 = PASS (모든 패턴 검출)
#   1 = FAIL (1건 이상 누락)

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
SCHEMA="$SERVER/prisma/schema.prisma"
GATEWAY_PORT="$SERVER/src/domain/port/outbound/payment-gateway.port.ts"
ADAPTER="$SERVER/src/adapter/outbound/payment/polar.adapter.ts"
USECASE="$SERVER/src/application/payment/payment.usecase.ts"
REPO_PORT="$SERVER/src/domain/port/outbound/webhook-event-repository.port.ts"
MIG_DIR="$SERVER/prisma/migrations"

PASS=0
FAIL=0
WARN=0

echo "=== sensor-payment-idempotency ($(date '+%H:%M:%S')) ==="
echo ""

# ── 1. WebhookEvent Prisma 모델 ──
if grep -qE 'model WebhookEvent' "$SCHEMA" 2>/dev/null; then
  echo "  [PASS] WebhookEvent Prisma 모델 존재"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] WebhookEvent Prisma 모델 누락 — schema.prisma"
  FAIL=$((FAIL + 1))
fi

# ── 2. eventId @unique ──
if grep -qE 'eventId\s+String\s+@unique' "$SCHEMA" 2>/dev/null; then
  echo "  [PASS] eventId @unique 제약 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] eventId @unique 제약 누락 — race 차단 부재"
  FAIL=$((FAIL + 1))
fi

# ── 3. NormalizedWebhookEvent.eventId 필드 ──
if grep -qE 'eventId:\s*string' "$GATEWAY_PORT" 2>/dev/null; then
  echo "  [PASS] NormalizedWebhookEvent.eventId 필드 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] NormalizedWebhookEvent.eventId 필드 누락"
  FAIL=$((FAIL + 1))
fi

# ── 4. polar.adapter webhook-id 헤더 추출 ──
if grep -qE "webhook-id|'webhook-id'" "$ADAPTER" 2>/dev/null; then
  echo "  [PASS] polar.adapter가 webhook-id 헤더 추출"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] polar.adapter webhook-id 헤더 미추출 — eventId 누락"
  FAIL=$((FAIL + 1))
fi

# ── 5. payment.usecase.processWebhook findByEventId 게이트 ──
if grep -qE 'findByEventId' "$USECASE" 2>/dev/null; then
  echo "  [PASS] payment.usecase.processWebhook findByEventId 게이트 사용"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] processWebhook findByEventId 게이트 미사용 — 멱등성 부재"
  FAIL=$((FAIL + 1))
fi

# ── 6. WebhookEventRepositoryPort 존재 ──
if [ -f "$REPO_PORT" ]; then
  echo "  [PASS] WebhookEventRepositoryPort 인터페이스 존재"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] WebhookEventRepositoryPort 누락 — DI 추상화 미흡"
  FAIL=$((FAIL + 1))
fi

# ── 7. Prisma 마이그레이션 파일 ──
if ls "$MIG_DIR" 2>/dev/null | grep -q webhook_event_idempotency; then
  echo "  [PASS] Prisma 마이그레이션 파일 존재"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Prisma 마이그레이션 파일 누락"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL / WARN: $WARN"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 누락 (PAY-P0-1 회귀)"
  exit 1
fi

echo "[RESULT] PASS — 멱등성 패턴 모두 박제"
exit 0
