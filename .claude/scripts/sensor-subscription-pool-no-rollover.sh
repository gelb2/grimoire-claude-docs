#!/bin/bash
# sensor-subscription-pool-no-rollover
# 크레딧 개편 I Phase (게이트 4 / §8-8 CRITICAL #2) — 구독 풀 이월 금지 정합 검증.
#
# §8-8 #2 — 풀 이월 금지. 무제한 이월 시 §0 0.14× 붕괴.
# 4-C 구조 — CreditLedger(source='subscription') row 의 expiresAt 만료 → 잔액 집계 제외.
#
# 검증 대상:
#   1. membership-tier.ts MEMBERSHIP_MONTHLY_POOL (free 0 / pro 93000 / premium 191500)
#   2. schema.prisma MembershipPlan 모델 신설
#   3. MembershipPlan poolBalance/poolResetAt/monthlyPoolPoints 컬럼
#   4. CreditLedger expiresAt 컬럼 (구독풀 만료 — 이월 차단 핵심)
#   5. CreditLedgerType 에 'expire' 포함
#   6. membership-plan.port.ts resetMonthlyPool 시그니처
#   7. prisma-membership-plan.repository.ts — resetMonthlyPool 이 monthlyPoolPoints 로 재설정 (이월 X)
#   8. reset-monthly-pool.job.ts @Cron 박제
#   9. 리셋 시 expire ledger 생성 (이월 차단 박제)
#
# Exit codes:
#   0 = PASS / 1 = FAIL

trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
SCHEMA="$SERVER/prisma/schema.prisma"
TIER_MODEL="$SERVER/src/domain/model/membership-tier.ts"
PLAN_PORT="$SERVER/src/domain/port/outbound/membership-plan.port.ts"
PLAN_ADAPTER="$SERVER/src/adapter/outbound/persistence/prisma-membership-plan.repository.ts"
RESET_JOB="$SERVER/src/application/subscription/reset-monthly-pool.job.ts"
SOURCE_MODEL="$SERVER/src/domain/model/credit-source.ts"

PASS=0
FAIL=0

echo "=== sensor-subscription-pool-no-rollover ($(date '+%H:%M:%S')) ==="
echo ""

# 1. MEMBERSHIP_MONTHLY_POOL §8-3 확정값
if grep -qE 'pro: 93000' "$TIER_MODEL" 2>/dev/null \
  && grep -qE 'premium: 191500' "$TIER_MODEL" 2>/dev/null \
  && grep -qE 'free: 0' "$TIER_MODEL" 2>/dev/null; then
  echo "  [PASS] membership-tier.ts 월 풀 §8-3 확정값 (free 0 / pro 93000 / premium 191500)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] MEMBERSHIP_MONTHLY_POOL §8-3 확정값 불일치"
  FAIL=$((FAIL + 1))
fi

# 2. MembershipPlan 모델
if grep -qE 'model MembershipPlan' "$SCHEMA" 2>/dev/null; then
  echo "  [PASS] schema.prisma MembershipPlan 모델 신설"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] MembershipPlan 모델 누락"
  FAIL=$((FAIL + 1))
fi

# 3. MembershipPlan 컬럼
PLAN_BLOCK=$(sed -n '/model MembershipPlan/,/^}/p' "$SCHEMA")
if echo "$PLAN_BLOCK" | grep -qE 'poolBalance' \
  && echo "$PLAN_BLOCK" | grep -qE 'poolResetAt' \
  && echo "$PLAN_BLOCK" | grep -qE 'monthlyPoolPoints'; then
  echo "  [PASS] MembershipPlan poolBalance/poolResetAt/monthlyPoolPoints 컬럼"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] MembershipPlan 풀 컬럼 누락"
  FAIL=$((FAIL + 1))
fi

# 4. CreditLedger expiresAt — 이월 차단 핵심
if sed -n '/model CreditLedger/,/^}/p' "$SCHEMA" | grep -qE 'expiresAt'; then
  echo "  [PASS] CreditLedger expiresAt 컬럼 (구독풀 만료 — 이월 차단 핵심)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] CreditLedger expiresAt 누락 — 이월이 코드 버그로 발생 가능 (§8-8 #2 위반)"
  FAIL=$((FAIL + 1))
fi

# 5. CreditLedgerType 'expire'
if grep -qE "'expire'" "$SOURCE_MODEL" 2>/dev/null; then
  echo "  [PASS] CreditLedgerType 에 'expire' 포함 (구독풀 만료 type)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] CreditLedgerType 'expire' 누락"
  FAIL=$((FAIL + 1))
fi

# 6. membership-plan.port.ts resetMonthlyPool
if [ -f "$PLAN_PORT" ] && grep -qE 'resetMonthlyPool' "$PLAN_PORT" 2>/dev/null \
  && grep -qE 'findPlansToReset' "$PLAN_PORT" 2>/dev/null; then
  echo "  [PASS] membership-plan.port.ts resetMonthlyPool/findPlansToReset 시그니처"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] membership-plan.port.ts 리셋 시그니처 누락"
  FAIL=$((FAIL + 1))
fi

# 7. resetMonthlyPool 이 monthlyPoolPoints 로 재설정 (이월 X — 가산 아님)
if grep -qE 'poolBalance: newPool' "$PLAN_ADAPTER" 2>/dev/null \
  && grep -qE 'pointsSubscription: newPool' "$PLAN_ADAPTER" 2>/dev/null; then
  echo "  [PASS] resetMonthlyPool 이 풀을 monthlyPoolPoints 로 재설정 (이월 X — 덮어씀)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] resetMonthlyPool 이 이월(가산) 위험 — 풀 재설정 미확인"
  FAIL=$((FAIL + 1))
fi

# 8. reset-monthly-pool.job.ts @Cron
if [ -f "$RESET_JOB" ] && grep -qE '@Cron' "$RESET_JOB" 2>/dev/null; then
  echo "  [PASS] reset-monthly-pool.job.ts @Cron 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] reset-monthly-pool.job.ts @Cron 누락"
  FAIL=$((FAIL + 1))
fi

# 9. 리셋 시 expire ledger 생성 (이월 차단 박제)
if grep -qE "type: 'expire'" "$PLAN_ADAPTER" 2>/dev/null; then
  echo "  [PASS] resetMonthlyPool 이 잔여 풀을 expire ledger 로 만료 (이월 차단)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] expire ledger 생성 누락 — 잔여 풀 이월 위험 (§8-8 #2 위반)"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 (구독 풀 이월 금지 정합 누락 — §0 0.14× 붕괴 위험)"
  exit 1
fi

echo "[RESULT] PASS — 구독 월 풀 이월 금지 정합 모두 박제"
exit 0
