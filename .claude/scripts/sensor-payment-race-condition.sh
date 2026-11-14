#!/bin/bash
# sensor-payment-race-condition.sh
# PAY-P3-A 회귀 차단 — payment.status 사전 게이트(구멍-A) + refundPaymentAtomically CAS 패턴(구멍-B) grep
#
# 정본: .claude/shared-contracts.md §22 PaymentRaceCondition
#
# 검증 영역 (8건):
#   1. payment.usecase.ts — payment.status='refunded' 사전 게이트 grep
#   2. payment.usecase.ts — payment.status='partial_refunded' 사전 게이트 grep
#   3. payment.usecase.ts — [PaymentRaceCondition] logger.warn 박제
#   4. payment.usecase.ts — already_refunded / already_partial_refunded 박제
#   5. prisma-payment.repository.ts — FOR UPDATE 비관락 + payment null guard (race 차단 진입)
#      [불변 시그널] findUniqueOrThrow → FOR UPDATE + findUnique+null throw 로 대체(CC-2b 이후)
#   6. prisma-payment.repository.ts — raw SQL CAS (>= $N decrement + 0 row throw) 패턴 박제
#      [불변 시그널] updateMany+gte → $executeRawUnsafe(WHERE col >= $1) CAS 로 변경(PAY-S2 이후)
#   7. prisma-payment.repository.ts — CAS_MISMATCH throw 박제 (호출자 retry 위임)
#   8. shared-contracts.md §22 PaymentRaceCondition 박제
#
# Exit codes:
#   0 = PASS / 1 = FAIL

# sensor-log 자동 박제 (트랙 1-A 정합)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
PAYMENT_USECASE="$SERVER/src/application/payment/payment.usecase.ts"
PRISMA_REPO="$SERVER/src/adapter/outbound/persistence/prisma-payment.repository.ts"
SHARED_CONTRACTS="$ROOT/.claude/shared-contracts.md"

PASS=0
FAIL=0

echo "=== sensor-payment-race-condition ($(date '+%H:%M:%S')) ==="
echo ""

# 1. payment.status='refunded' 사전 게이트 (PAY-P3-D 영역 isPaymentAlreadyRefunded helper 영역 정합)
if grep -qE "payment\.status\s*===\s*'refunded'|isPaymentAlreadyRefunded\(payment\.status\)" "$PAYMENT_USECASE" 2>/dev/null; then
  echo "  [PASS] payment.usecase: payment.status='refunded' 사전 게이트 박제 (helper 영역 정합)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] payment.usecase: payment.status='refunded' 사전 게이트 누락 — 구멍-A 회귀"
  FAIL=$((FAIL + 1))
fi

# 2. payment.status='partial_refunded' 사전 게이트 (PAY-P3-D 영역 isPaymentAlreadyRefunded helper 영역 정합)
if grep -qE "payment\.status\s*===\s*'partial_refunded'|isPaymentAlreadyRefunded\(payment\.status\)" "$PAYMENT_USECASE" 2>/dev/null; then
  echo "  [PASS] payment.usecase: payment.status='partial_refunded' 사전 게이트 박제 (helper 영역 정합)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] payment.usecase: payment.status='partial_refunded' 사전 게이트 누락 — 구멍-A 회귀"
  FAIL=$((FAIL + 1))
fi

# 3. [PaymentRaceCondition] logger.warn (incident 박제 의무 정합)
if grep -qE '\[PaymentRaceCondition\]' "$PAYMENT_USECASE" 2>/dev/null; then
  echo "  [PASS] payment.usecase: [PaymentRaceCondition] logger.warn 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] payment.usecase: [PaymentRaceCondition] 로깅 누락 — incident 박제 의무 회귀"
  FAIL=$((FAIL + 1))
fi

# 4. already_refunded / already_partial_refunded reason 박제
if grep -qE "already_refunded|already_partial_refunded" "$PAYMENT_USECASE" 2>/dev/null; then
  echo "  [PASS] payment.usecase: already_refunded / already_partial_refunded reason 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] payment.usecase: skip reason 박제 누락"
  FAIL=$((FAIL + 1))
fi

# 5. FOR UPDATE 비관락 + payment null guard (race 진입 명시)
#   불변 시그널: findUniqueOrThrow → FOR UPDATE 직렬화 + findUnique 후 null throw 로 대체(CC-2b).
#   동작 동치(없는 row 시 throw) 검증 — 비관락 존재 AND null guard 존재.
if grep -qE 'FOR UPDATE' "$PRISMA_REPO" 2>/dev/null && \
   grep -qE 'if \(!payment\)' "$PRISMA_REPO" 2>/dev/null; then
  echo "  [PASS] prisma-payment.repository: FOR UPDATE 비관락 + payment null guard 박제 (구멍-B 진입)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] prisma-payment.repository: FOR UPDATE / payment null guard 누락 — race 진입 부재"
  FAIL=$((FAIL + 1))
fi

# 6. raw SQL CAS 패턴 (WHERE col >= $N decrement + 0 row throw)
#   불변 시그널: updateMany+gte → $executeRawUnsafe CAS 로 변경(PAY-S2). 형태 비의존.
#   동시 트랜잭션이 잔액 변경 시 0 row → throw 하는 CAS 가드 = `>= $N` 조건 AND CAS_MISMATCH throw.
if grep -qE '>=\s*\$[0-9]' "$PRISMA_REPO" 2>/dev/null && grep -qE 'CAS_MISMATCH' "$PRISMA_REPO" 2>/dev/null; then
  echo "  [PASS] prisma-payment.repository: raw SQL CAS (WHERE col >= \$N + CAS_MISMATCH throw) 박제 (구멍-B 차단)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] prisma-payment.repository: CAS 패턴 누락 — race window 회귀"
  FAIL=$((FAIL + 1))
fi

# 7. CAS_MISMATCH throw (호출자 retry 위임)
if grep -qE 'CAS_MISMATCH' "$PRISMA_REPO" 2>/dev/null; then
  echo "  [PASS] prisma-payment.repository: CAS_MISMATCH throw 박제 (DLQ retry 위임)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] prisma-payment.repository: CAS_MISMATCH 처리 누락"
  FAIL=$((FAIL + 1))
fi

# 8. shared-contracts §22 박제
if grep -qE '## 22\. PaymentRaceCondition' "$SHARED_CONTRACTS" 2>/dev/null; then
  echo "  [PASS] shared-contracts §22 PaymentRaceCondition 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] shared-contracts §22 PaymentRaceCondition 누락 — 인터페이스 정본 부재"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 누락 (PAY-P3-A race condition 차단 회귀)"
  exit 1
fi

echo "[RESULT] PASS — race condition 차단 패턴 (구멍-A 사전 게이트 + 구멍-B CAS) 모두 박제"
exit 0
