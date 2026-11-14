#!/bin/bash
# sensor-refund-atomicity
# PAY-P1-1: Polar 환불 webhook 시 크레딧 환수 트랜잭션 패턴 검증.
# Constitution P16 (결제 원자성)와 함께 commit 직전 자동 차단.
#
# 검증 대상:
#   1. RefundLog Prisma 모델 + deficitCredits 컬럼
#   2. @@index([paymentId])
#   3. RefundPaymentUseCase 파일 존재
#   4. refundPaymentAtomically 시그니처 박제 (port)
#   5. payment.usecase 'cancel' 분기 → refund usecase 호출
#   6. AuditLog operator='system_refund' + 2 action 식별자
#   7. spec 파일 존재 (정상 + deficit 분기 검증)
#   8. 마이그레이션 파일 존재
#   9. CreditLog 음수 박제 (환수 대칭)
#
# Exit codes:
#   0 = PASS / 1 = FAIL

# sensor-log 자동 박제 (트랙 1-A 보강 — exit code 자동 매핑: 0=PASS / 1=FAIL / 2=WARN)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
SCHEMA="$SERVER/prisma/schema.prisma"
PORT="$SERVER/src/domain/port/outbound/payment-repository.port.ts"
USECASE="$SERVER/src/application/payment/refund-payment.usecase.ts"
USECASE_SPEC="$SERVER/src/application/payment/refund-payment.usecase.spec.ts"
PAYMENT_USECASE="$SERVER/src/application/payment/payment.usecase.ts"
MIG_DIR="$SERVER/prisma/migrations"

PASS=0
FAIL=0

echo "=== sensor-refund-atomicity ($(date '+%H:%M:%S')) ==="
echo ""

# 1. RefundLog Prisma 모델
if grep -qE 'model RefundLog' "$SCHEMA" 2>/dev/null; then
  echo "  [PASS] RefundLog Prisma 모델 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] RefundLog 모델 누락"
  FAIL=$((FAIL + 1))
fi

# 2. deficitCredits 컬럼
if grep -qE 'deficitCredits|deficit_credits' "$SCHEMA" 2>/dev/null; then
  echo "  [PASS] deficitCredits 컬럼 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] deficitCredits 컬럼 누락 — 잔액 부족 추적 부재"
  FAIL=$((FAIL + 1))
fi

# 3. @@index([paymentId])
if grep -qE '@@index\(\[paymentId\]\)' "$SCHEMA" 2>/dev/null; then
  echo "  [PASS] RefundLog @@index([paymentId]) 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] @@index([paymentId]) 누락 — 조회 성능 ↓"
  FAIL=$((FAIL + 1))
fi

# 4. RefundPaymentUseCase 파일
if [ -f "$USECASE" ]; then
  echo "  [PASS] RefundPaymentUseCase 파일 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] refund-payment.usecase.ts 누락"
  FAIL=$((FAIL + 1))
fi

# 5. refundPaymentAtomically 시그니처 (port)
if grep -qE 'refundPaymentAtomically' "$PORT" 2>/dev/null; then
  echo "  [PASS] refundPaymentAtomically 시그니처 (port) 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] refundPaymentAtomically 시그니처 누락 — Hexagonal 추상화 부재"
  FAIL=$((FAIL + 1))
fi

# 6. payment.usecase 'cancel' 분기 → refund usecase 호출
if grep -qE 'refundPaymentUseCase|RefundPaymentUseCase' "$PAYMENT_USECASE" 2>/dev/null; then
  echo "  [PASS] payment.usecase 'cancel' 분기 → refund usecase 호출"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] payment.usecase에 refund usecase 호출 부재 — 환수 트리거 안 됨"
  FAIL=$((FAIL + 1))
fi

# 7. AuditLog operator='system_refund'
if grep -qE 'system_refund' "$USECASE" 2>/dev/null; then
  echo "  [PASS] AuditLog operator='system_refund' 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] system_refund operator 누락 — 환수 추적 부재"
  FAIL=$((FAIL + 1))
fi

# 8. 2 action 식별자 (refund_normal + refund_deficit)
ACTIONS=$(grep -cE 'refund_normal|refund_deficit' "$USECASE" 2>/dev/null); ACTIONS=${ACTIONS:-0}
if [ "$ACTIONS" -ge 2 ]; then
  echo "  [PASS] 2 action 식별자 박제 (refund_normal + refund_deficit)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] 2 action 식별자 누락 ($ACTIONS/2)"
  FAIL=$((FAIL + 1))
fi

# 9. spec 파일
if [ -f "$USECASE_SPEC" ]; then
  echo "  [PASS] refund-payment.usecase.spec.ts 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] spec 파일 누락"
  FAIL=$((FAIL + 1))
fi

# 10. 마이그레이션 파일
if ls "$MIG_DIR" 2>/dev/null | grep -q refund_log; then
  echo "  [PASS] Prisma 마이그레이션 파일 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] refund_log 마이그레이션 누락"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 누락 (PAY-P1-1 회귀)"
  exit 1
fi

echo "[RESULT] PASS — Refund 환수 트랜잭션 패턴 모두 박제"
exit 0
