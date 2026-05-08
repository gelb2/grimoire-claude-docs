#!/usr/bin/env bash
# sensor-partial-refund — PAY-P2-1 부분 환불 회귀 차단 (sprint #10_7)
#
# 발동 조건:
# - pre-commit / pre-push (server 변경 시)
# - 정기 회귀 (eval-runner)
#
# 정본 (단일 진실):
# - `reports/sprint-pay-p2-1-partial-refund-progress.md` §2 AC-1~AC-7
# - `.claude/shared-contracts.md` §17 PartialRefund
# - `reports/PAY-P2-MASTER-PLAN.md` §3
#
# 검증 영역 (10건):
# 1. PaymentRepositoryPort 시그니처 — proportionalCredits + isPartial 반환 박제
# 2. prisma-payment.repository — payment.amount 조회 (트랜잭션 내부)
# 3. prisma-payment.repository — ratio = refundedAmount / payment.amount 비율 계산
# 4. prisma-payment.repository — Math.floor(credits * ratio) 반올림 (사용자 우호)
# 5. prisma-payment.repository — refundedAmount > payment.amount 시 throw (validation)
# 6. prisma-payment.repository — Payment.status 'partial_refunded' / 'refunded' 분기
# 7. refund-payment.usecase — refundedAmount <= 0 BadRequestException
# 8. refund-payment.usecase — action 4 매트릭스 (refund_normal / _deficit / _partial / _partial_deficit)
# 9. refund-payment.usecase.spec — 부분 환불 describe 박제 + 6 it
# 10. 외부 프로젝트 인용 0건 (CERTI_PROJ / brightmall / thermage / inapi)
#
# Exit codes:
# - 0 PASS — 모두 정합
# - 2 FAIL — 회귀 검출 (commit 차단)

# sensor-log 자동 박제
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set +e

REPO_ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
SERVER="$REPO_ROOT/grimoire-server"
PORT="$SERVER/src/domain/port/outbound/payment-repository.port.ts"
REPO_IMPL="$SERVER/src/adapter/outbound/persistence/prisma-payment.repository.ts"
USECASE="$SERVER/src/application/payment/refund-payment.usecase.ts"
SPEC="$SERVER/src/application/payment/refund-payment.usecase.spec.ts"

echo "── sensor-partial-refund (PAY-P2-1 회귀 차단) ──"

PASS=0
FAIL=0

# [1/10] PaymentRepositoryPort 시그니처 — proportionalCredits + isPartial
if grep -nE 'proportionalCredits:\s*number' "$PORT" > /dev/null 2>&1 && \
   grep -nE 'isPartial:\s*boolean' "$PORT" > /dev/null 2>&1; then
  echo "  ✓ [1/10] PaymentRepositoryPort 시그니처 — proportionalCredits + isPartial 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [1/10] PaymentRepositoryPort 시그니처 누락"
  FAIL=$((FAIL+1))
fi

# [2/10] payment.amount 조회 (트랜잭션 내부)
if grep -nE 'tx\.payment\.findUnique.*\{[^}]*select:\s*\{[^}]*amount:\s*true' "$REPO_IMPL" > /dev/null 2>&1 || \
   grep -nE 'select:\s*\{\s*amount:\s*true' "$REPO_IMPL" > /dev/null 2>&1; then
  echo "  ✓ [2/10] payment.amount 조회 박제 (비율 계산용)"
  PASS=$((PASS+1))
else
  echo "  ✗ [2/10] payment.amount 조회 누락"
  FAIL=$((FAIL+1))
fi

# [3/10] ratio = refundedAmount / payment.amount
if grep -nE 'ratio\s*=\s*refundedAmount\s*/\s*payment\.amount' "$REPO_IMPL" > /dev/null 2>&1; then
  echo "  ✓ [3/10] ratio = refundedAmount / payment.amount 비율 계산 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [3/10] 비율 계산 패턴 누락"
  FAIL=$((FAIL+1))
fi

# [4/10] Math.floor(credits * ratio)
if grep -nE 'Math\.floor\(credits\s*\*\s*ratio\)' "$REPO_IMPL" > /dev/null 2>&1; then
  echo "  ✓ [4/10] Math.floor(credits * ratio) 반올림 박제 (사용자 우호)"
  PASS=$((PASS+1))
else
  echo "  ✗ [4/10] Math.floor 반올림 패턴 누락"
  FAIL=$((FAIL+1))
fi

# [5/10] refundedAmount > payment.amount 시 throw
if grep -nE 'refundedAmount\s*>\s*payment\.amount' "$REPO_IMPL" > /dev/null 2>&1; then
  echo "  ✓ [5/10] refundedAmount > payment.amount validation 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [5/10] validation 누락"
  FAIL=$((FAIL+1))
fi

# [6/10] Payment.status 분기 ('partial_refunded' / 'refunded')
if grep -nE "isPartial\s*\?\s*'partial_refunded'\s*:\s*'refunded'" "$REPO_IMPL" > /dev/null 2>&1; then
  echo "  ✓ [6/10] Payment.status 'partial_refunded' / 'refunded' 분기 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [6/10] status 분기 누락"
  FAIL=$((FAIL+1))
fi

# [7/10] refund-payment.usecase — refundedAmount <= 0 validation
if grep -nE 'refundedAmount\s*<=\s*0' "$USECASE" > /dev/null 2>&1; then
  echo "  ✓ [7/10] refund-payment.usecase refundedAmount <= 0 validation 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [7/10] usecase validation 누락"
  FAIL=$((FAIL+1))
fi

# [8/10] action 4 매트릭스 — refund_normal / _deficit / _partial / _partial_deficit
ACTIONS_FOUND=$(grep -cE "refund_normal|refund_deficit|refund_partial[^_]|refund_partial_deficit" "$USECASE")
if [ "$ACTIONS_FOUND" -ge 4 ]; then
  echo "  ✓ [8/10] action 4 매트릭스 박제 (refund_normal/_deficit/_partial/_partial_deficit, $ACTIONS_FOUND건 박제)"
  PASS=$((PASS+1))
else
  echo "  ✗ [8/10] action 매트릭스 부족 ($ACTIONS_FOUND건 < 4)"
  FAIL=$((FAIL+1))
fi

# [9/10] spec 부분 환불 describe + 6 it
if grep -nE "describe\(['\"]부분 환불.*PAY-P2-1" "$SPEC" > /dev/null 2>&1; then
  IT_COUNT=$(awk '/describe.*부분 환불.*PAY-P2-1/,/^  \}\)/' "$SPEC" | grep -cE "^\s*it\(['\"]")
  if [ "$IT_COUNT" -ge 6 ]; then
    echo "  ✓ [9/10] spec 부분 환불 describe + ≥6 it 박제 ($IT_COUNT건)"
    PASS=$((PASS+1))
  else
    echo "  ✗ [9/10] spec it 부족 ($IT_COUNT건 < 6)"
    FAIL=$((FAIL+1))
  fi
else
  echo "  ✗ [9/10] spec 부분 환불 describe 누락"
  FAIL=$((FAIL+1))
fi

# [10/10] 외부 프로젝트 인용 0건
EXT_HITS=$(grep -rEi 'CERTI_PROJ|brightmall|thermage|inapi' "$PORT" "$REPO_IMPL" "$USECASE" "$SPEC" 2>/dev/null)
if [ -z "$EXT_HITS" ]; then
  echo "  ✓ [10/10] 외부 프로젝트 인용 0건"
  PASS=$((PASS+1))
else
  echo "  ✗ [10/10] 외부 프로젝트 인용 검출"
  echo "$EXT_HITS" | head -3
  FAIL=$((FAIL+1))
fi

echo ""
echo "── 종합 ──"
echo "  PASS: $PASS / FAIL: $FAIL"

if [ $FAIL -gt 0 ]; then
  echo "  ✗ FAIL — PAY-P2-1 회귀 검출 (commit 차단)"
  echo "  → 정본: reports/sprint-pay-p2-1-partial-refund-progress.md §2 AC-1~AC-7"
  exit 2
fi

echo "  ✓ PASS — PAY-P2-1 부분 환불 정합"
exit 0
