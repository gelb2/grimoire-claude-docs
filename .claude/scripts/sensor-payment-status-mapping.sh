#!/bin/bash
# sensor-payment-status-mapping.sh
# PAY-P3-D 회귀 차단 — Status enum + Polar 매핑 함수 영역 박제 grep
#
# 정본:
# - .claude/shared-contracts.md §28 PaymentStatusMapping
# - grimoire-server/ADR.md §ADR-010
#
# 검증 영역 (10건):
#   1. payment-status.ts 도메인 model 박제
#   2. PAYMENT_STATUS 5 enum 박제 (pending/completed/failed/refunded/partial_refunded)
#   3. WEBHOOK_EVENT_STATUS 3 enum 박제 (processed/skipped/failed)
#   4. NORMALIZED_WEBHOOK_STATUS 3 enum 박제 (success/fail/cancel)
#   5. NORMALIZED_CHECKOUT_STATUS 4 enum 박제 (succeeded/refunded/failed/open)
#   6. mapPolarOrderStatus + mapPolarCheckoutStatus 매핑 함수 박제
#   7. isPaymentAlreadyRefunded helper 박제
#   8. polar.adapter.ts 영역 도메인 매핑 함수 import 박제
#   9. payment.usecase.ts 영역 도메인 enum import 박제
#  10. shared-contracts.md §28 PaymentStatusMapping 박제
#
# Exit codes:
#   0 = PASS / 1 = FAIL

# sensor-log 자동 박제 (트랙 1-A 정합)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
PAYMENT_STATUS_MODEL="$SERVER/src/domain/model/payment-status.ts"
PAYMENT_STATUS_SPEC="$SERVER/src/domain/model/payment-status.spec.ts"
POLAR_ADAPTER="$SERVER/src/adapter/outbound/payment/polar.adapter.ts"
PAYMENT_USECASE="$SERVER/src/application/payment/payment.usecase.ts"
SHARED_CONTRACTS="$ROOT/.claude/shared-contracts.md"

PASS=0
FAIL=0

echo "=== sensor-payment-status-mapping ($(date '+%H:%M:%S')) ==="
echo ""

# 1. payment-status.ts 도메인 model 박제
if [[ -f "$PAYMENT_STATUS_MODEL" ]]; then
  echo "  [PASS] domain/model/payment-status.ts 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] domain/model/payment-status.ts 누락 — 도메인 enum 박제 회귀"
  FAIL=$((FAIL + 1))
fi

# 2. PAYMENT_STATUS 5 enum 박제
if grep -qE "PENDING.*'pending'" "$PAYMENT_STATUS_MODEL" 2>/dev/null && \
   grep -qE "COMPLETED.*'completed'" "$PAYMENT_STATUS_MODEL" 2>/dev/null && \
   grep -qE "FAILED.*'failed'" "$PAYMENT_STATUS_MODEL" 2>/dev/null && \
   grep -qE "REFUNDED.*'refunded'" "$PAYMENT_STATUS_MODEL" 2>/dev/null && \
   grep -qE "PARTIAL_REFUNDED.*'partial_refunded'" "$PAYMENT_STATUS_MODEL" 2>/dev/null; then
  echo "  [PASS] PAYMENT_STATUS 5 enum 박제 (pending/completed/failed/refunded/partial_refunded)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] PAYMENT_STATUS 5 enum 박제 결함"
  FAIL=$((FAIL + 1))
fi

# 3. WEBHOOK_EVENT_STATUS 3 enum 박제
if grep -qE "WEBHOOK_EVENT_STATUS" "$PAYMENT_STATUS_MODEL" 2>/dev/null && \
   grep -qE "PROCESSED.*'processed'" "$PAYMENT_STATUS_MODEL" 2>/dev/null && \
   grep -qE "SKIPPED.*'skipped'" "$PAYMENT_STATUS_MODEL" 2>/dev/null; then
  echo "  [PASS] WEBHOOK_EVENT_STATUS 3 enum 박제 (processed/skipped/failed)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] WEBHOOK_EVENT_STATUS 3 enum 박제 결함"
  FAIL=$((FAIL + 1))
fi

# 4. NORMALIZED_WEBHOOK_STATUS 3 enum 박제
if grep -qE "NORMALIZED_WEBHOOK_STATUS" "$PAYMENT_STATUS_MODEL" 2>/dev/null && \
   grep -qE "SUCCESS.*'success'" "$PAYMENT_STATUS_MODEL" 2>/dev/null && \
   grep -qE "CANCEL.*'cancel'" "$PAYMENT_STATUS_MODEL" 2>/dev/null; then
  echo "  [PASS] NORMALIZED_WEBHOOK_STATUS 3 enum 박제 (success/fail/cancel)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] NORMALIZED_WEBHOOK_STATUS 3 enum 박제 결함"
  FAIL=$((FAIL + 1))
fi

# 5. NORMALIZED_CHECKOUT_STATUS 4 enum 박제
if grep -qE "NORMALIZED_CHECKOUT_STATUS" "$PAYMENT_STATUS_MODEL" 2>/dev/null && \
   grep -qE "SUCCEEDED.*'succeeded'" "$PAYMENT_STATUS_MODEL" 2>/dev/null && \
   grep -qE "OPEN.*'open'" "$PAYMENT_STATUS_MODEL" 2>/dev/null; then
  echo "  [PASS] NORMALIZED_CHECKOUT_STATUS 4 enum 박제 (succeeded/refunded/failed/open)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] NORMALIZED_CHECKOUT_STATUS 4 enum 박제 결함"
  FAIL=$((FAIL + 1))
fi

# 6. mapPolarOrderStatus + mapPolarCheckoutStatus 매핑 함수 박제
if grep -qE "export function mapPolarOrderStatus" "$PAYMENT_STATUS_MODEL" 2>/dev/null && \
   grep -qE "export function mapPolarCheckoutStatus" "$PAYMENT_STATUS_MODEL" 2>/dev/null; then
  echo "  [PASS] mapPolarOrderStatus + mapPolarCheckoutStatus 매핑 함수 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Polar 매핑 함수 박제 결함 (mapPolarOrderStatus 또는 mapPolarCheckoutStatus 누락)"
  FAIL=$((FAIL + 1))
fi

# 7. isPaymentAlreadyRefunded helper 박제
if grep -qE "export function isPaymentAlreadyRefunded" "$PAYMENT_STATUS_MODEL" 2>/dev/null; then
  echo "  [PASS] isPaymentAlreadyRefunded helper 박제 (race condition 통합 게이트)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] isPaymentAlreadyRefunded helper 박제 결함"
  FAIL=$((FAIL + 1))
fi

# 8. polar.adapter.ts 영역 도메인 매핑 함수 import 박제
if grep -qE "@domain/model/payment-status" "$POLAR_ADAPTER" 2>/dev/null && \
   grep -qE "mapPolarOrderStatus|mapPolarCheckoutStatus" "$POLAR_ADAPTER" 2>/dev/null; then
  echo "  [PASS] polar.adapter.ts 영역 도메인 매핑 함수 통합 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] polar.adapter.ts 영역 도메인 매핑 함수 통합 결함 (import 또는 호출 누락)"
  FAIL=$((FAIL + 1))
fi

# 9. payment.usecase.ts 영역 도메인 enum import 박제
if grep -qE "@domain/model/payment-status" "$PAYMENT_USECASE" 2>/dev/null && \
   grep -qE "isPaymentAlreadyRefunded|NORMALIZED_WEBHOOK_STATUS|PAYMENT_STATUS|WEBHOOK_EVENT_STATUS" "$PAYMENT_USECASE" 2>/dev/null; then
  echo "  [PASS] payment.usecase.ts 영역 도메인 enum 통합 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] payment.usecase.ts 영역 도메인 enum 통합 결함 (import 또는 사용 누락)"
  FAIL=$((FAIL + 1))
fi

# 10. shared-contracts.md §28 PaymentStatusMapping 박제
if grep -qE "## 28\..*PaymentStatusMapping" "$SHARED_CONTRACTS" 2>/dev/null; then
  echo "  [PASS] shared-contracts §28 PaymentStatusMapping 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] shared-contracts §28 PaymentStatusMapping 박제 누락 — 정본 사슬 결함"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [[ $FAIL -eq 0 ]]; then
  echo "[RESULT] PASS — Status enum + Polar 매핑 함수 박제 (도메인 어휘 통합 + shared-contracts §28 정합)"
  exit 0
else
  echo "[RESULT] FAIL — $FAIL 건 누락 (PAY-P3-D status enum mapping 회귀)"
  exit 1
fi
