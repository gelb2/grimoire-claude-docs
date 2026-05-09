#!/bin/bash
# sensor-retry-dedup.sh
# PAY-P3-C 회귀 차단 — webhook-retry.job 사전 dedup 게이트 + AuditLog retry_skip_dedup grep
#
# 정본: .claude/shared-contracts.md §23 RetryDeduplication
#
# 검증 영역 (8건):
#   1. webhook-retry.job.ts — PaymentRepositoryPort import 박제
#   2. webhook-retry.job.ts — paymentRepo DI 주입 박제
#   3. webhook-retry.job.ts — payment.status='completed' dedup 게이트 (FINALIZED_STATUSES)
#   4. webhook-retry.job.ts — payment.status='refunded' dedup 게이트 (FINALIZED_STATUSES)
#   5. webhook-retry.job.ts — payment.status='partial_refunded' dedup 게이트 (FINALIZED_STATUSES)
#   6. webhook-retry.job.ts — AuditLog action='retry_skip_dedup' 박제
#   7. webhook-retry.job.ts — logger.log dedup=N 통계 박제
#   8. shared-contracts.md §23 RetryDeduplication 박제
#
# Exit codes:
#   0 = PASS / 1 = FAIL

# sensor-log 자동 박제 (트랙 1-A 정합)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
RETRY_JOB="$SERVER/src/application/payment/webhook-retry.job.ts"
SHARED_CONTRACTS="$ROOT/.claude/shared-contracts.md"

PASS=0
FAIL=0

echo "=== sensor-retry-dedup ($(date '+%H:%M:%S')) ==="
echo ""

# 1. PaymentRepositoryPort import 박제
if grep -qE "import.*PaymentRepositoryPort.*from.*payment-repository" "$RETRY_JOB" 2>/dev/null; then
  echo "  [PASS] webhook-retry.job: PaymentRepositoryPort import 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] webhook-retry.job: PaymentRepositoryPort import 누락 — DI 주입 부재"
  FAIL=$((FAIL + 1))
fi

# 2. paymentRepo DI 주입 (@Inject('PaymentRepositoryPort'))
if grep -qE "@Inject\(['\"]PaymentRepositoryPort['\"]\)" "$RETRY_JOB" 2>/dev/null; then
  echo "  [PASS] webhook-retry.job: @Inject('PaymentRepositoryPort') 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] webhook-retry.job: paymentRepo DI 주입 누락 — 사전 게이트 진입 불가"
  FAIL=$((FAIL + 1))
fi

# 3. payment.status='completed' dedup 게이트 (FINALIZED_STATUSES Set 또는 직접 비교)
if grep -qE "['\"]completed['\"]" "$RETRY_JOB" 2>/dev/null && grep -qE "FINALIZED_STATUSES|payment\.status" "$RETRY_JOB" 2>/dev/null; then
  echo "  [PASS] webhook-retry.job: payment.status='completed' dedup 게이트 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] webhook-retry.job: completed dedup 게이트 누락 — 모순-D 회귀"
  FAIL=$((FAIL + 1))
fi

# 4. payment.status='refunded' dedup 게이트
if grep -qE "['\"]refunded['\"]" "$RETRY_JOB" 2>/dev/null; then
  echo "  [PASS] webhook-retry.job: payment.status='refunded' dedup 게이트 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] webhook-retry.job: refunded dedup 게이트 누락"
  FAIL=$((FAIL + 1))
fi

# 5. payment.status='partial_refunded' dedup 게이트
if grep -qE "['\"]partial_refunded['\"]" "$RETRY_JOB" 2>/dev/null; then
  echo "  [PASS] webhook-retry.job: payment.status='partial_refunded' dedup 게이트 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] webhook-retry.job: partial_refunded dedup 게이트 누락"
  FAIL=$((FAIL + 1))
fi

# 6. AuditLog action='retry_skip_dedup' 박제
if grep -qE "retry_skip_dedup" "$RETRY_JOB" 2>/dev/null; then
  echo "  [PASS] webhook-retry.job: AuditLog action='retry_skip_dedup' 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] webhook-retry.job: retry_skip_dedup AuditLog 누락 — 운영 추적 부재"
  FAIL=$((FAIL + 1))
fi

# 7. logger.log dedup=N 통계 박제
if grep -qE 'dedup=\$\{skipDedupCount\}|skipDedupCount' "$RETRY_JOB" 2>/dev/null; then
  echo "  [PASS] webhook-retry.job: logger.log dedup=N 통계 + skipDedupCount 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] webhook-retry.job: dedup=N 통계 누락 — 운영 cron logs 정합 부재"
  FAIL=$((FAIL + 1))
fi

# 8. shared-contracts §23 박제
if grep -qE '## 23\. RetryDeduplication' "$SHARED_CONTRACTS" 2>/dev/null; then
  echo "  [PASS] shared-contracts §23 RetryDeduplication 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] shared-contracts §23 RetryDeduplication 누락 — 인터페이스 정본 부재"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 누락 (PAY-P3-C retry dedup 차단 회귀)"
  exit 1
fi

echo "[RESULT] PASS — retry dedup 차단 패턴 (사전 게이트 + AuditLog + 통계) 모두 박제"
exit 0
