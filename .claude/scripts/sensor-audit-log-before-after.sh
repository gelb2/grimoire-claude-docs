#!/usr/bin/env bash
# sensor-audit-log-before-after — PAY-P2-4 AdminAuditLog 정밀화 회귀 차단
#
# 발동 조건:
# - pre-commit / pre-push (server 변경 시)
# - 정기 회귀 (eval-runner)
#
# 정본 (단일 진실):
# - `reports/sprint-pay-p2-4-audit-strengthening-progress.md` §2 AC-1~AC-7
# - `.claude/shared-contracts.md` §20 AdminAuditLog beforeState/afterState Convention
#
# 검증 영역 (10건):
# 1. audit-log.service.ts beforeState? optional 시그니처
# 2. audit-log.service.ts afterState? optional 시그니처
# 3. audit-log.service.ts BACKWARD COMPATIBILITY spread 패턴 (hasBefore/hasAfter)
# 4. audit-log.service.spec.ts 신설 + ≥6 it
# 5. admin.usecase.ts grantCredits 6-arg auditLog.log 호출
# 6. admin.usecase.ts deductCredits 6-arg auditLog.log 호출
# 7. payment.usecase.ts payment_completed action 박제
# 8. refund-payment.usecase.ts auditLog.log beforeState/afterState 박제
# 9. spec assertion ≥6건 (의미 있는 — toHaveBeenCalledWith)
# 10. 외부 프로젝트 인용 0건
#
# Exit codes (sensor 패턴 정합):
# - 0 PASS — 모두 정합
# - 1 WARN — 일부 정책 미준수 (commit 허용)
# - 2 FAIL — AC 미충족 (commit 차단)

# sensor-log 자동 박제 (PP 묶음 정합)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 2

SERVER="grimoire-server"

if [ ! -d "$SERVER" ]; then
  echo "  ⚠ grimoire-server 디렉토리 없음 — sensor 면제"
  exit 0
fi

echo "── sensor-audit-log-before-after (PAY-P2-4 회귀 차단) ──"

PASS=0
FAIL=0

check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✓ $desc"
    PASS=$((PASS+1))
  else
    echo "  ✗ $desc"
    FAIL=$((FAIL+1))
  fi
}

# 1. beforeState? optional 시그니처
check "[1/10] audit-log.service.ts beforeState? optional 박제" \
  grep -qE "beforeState\?: Record<string, unknown>" "$SERVER/src/application/admin/audit-log.service.ts"

# 2. afterState? optional 시그니처
check "[2/10] audit-log.service.ts afterState? optional 박제" \
  grep -qE "afterState\?: Record<string, unknown>" "$SERVER/src/application/admin/audit-log.service.ts"

# 3. BACKWARD COMPATIBILITY spread 패턴
check "[3/10] BACKWARD COMPATIBILITY hasBefore/hasAfter spread 박제" \
  bash -c "grep -qE 'hasBefore' '$SERVER/src/application/admin/audit-log.service.ts' && grep -qE 'hasAfter' '$SERVER/src/application/admin/audit-log.service.ts'"

# 4. audit-log.service.spec.ts 신설 + ≥6 it
SPEC_FILE="$SERVER/src/application/admin/audit-log.service.spec.ts"
if [ -f "$SPEC_FILE" ]; then
  IT_COUNT=$(grep -cE "^\\s*it\\(" "$SPEC_FILE" 2>/dev/null); IT_COUNT=${IT_COUNT:-0}
  if [ "$IT_COUNT" -ge 6 ]; then
    echo "  ✓ [4/10] audit-log.service.spec.ts 신설 + $IT_COUNT it (≥6)"
    PASS=$((PASS+1))
  else
    echo "  ✗ [4/10] audit-log.service.spec.ts it 부족 ($IT_COUNT < 6)"
    FAIL=$((FAIL+1))
  fi
else
  echo "  ✗ [4/10] audit-log.service.spec.ts 미존재"
  FAIL=$((FAIL+1))
fi

# 5. admin.usecase.ts grantCredits 6-arg
check "[5/10] admin.usecase.ts grantCredits beforeState/afterState 박제" \
  bash -c "grep -B 2 -A 8 'grantCredits' '$SERVER/src/application/admin/admin.usecase.ts' | grep -qE 'beforeState'"

# 6. admin.usecase.ts deductCredits 6-arg
check "[6/10] admin.usecase.ts deductCredits beforeState/afterState 박제" \
  bash -c "grep -B 2 -A 8 'deductCredits' '$SERVER/src/application/admin/admin.usecase.ts' | grep -qE 'beforeState'"

# 7. payment.usecase.ts payment_completed action
check "[7/10] payment.usecase.ts payment_completed action 박제" \
  grep -qE "payment_completed" "$SERVER/src/application/payment/payment.usecase.ts"

# 8. refund-payment.usecase.ts auditLog beforeState/afterState
check "[8/10] refund-payment.usecase.ts beforeState/afterState 박제" \
  bash -c "grep -qE 'beforeState' '$SERVER/src/application/payment/refund-payment.usecase.ts' && grep -qE 'afterState' '$SERVER/src/application/payment/refund-payment.usecase.ts'"

# 9. spec assertion ≥6건 (의미 있는)
ASSERT_COUNT=$(grep -cE "toHaveBeenCalledWith|toMatchObject|toEqual|toHaveProperty|not.toHaveProperty" "$SPEC_FILE" 2>/dev/null); ASSERT_COUNT=${ASSERT_COUNT:-0}
if [ "$ASSERT_COUNT" -ge 6 ]; then
  echo "  ✓ [9/10] 의미 있는 assertion ≥6건 ($ASSERT_COUNT)"
  PASS=$((PASS+1))
else
  echo "  ✗ [9/10] 의미 있는 assertion 부족 ($ASSERT_COUNT < 6)"
  FAIL=$((FAIL+1))
fi

# 10. 외부 프로젝트 인용 0건 (PAY-P2-4 영역만)
EXT_HITS=$(grep -rE 'CERTI_PROJ|brightmall|thermage|inapi|admin-certilife|no1-sass' \
  "$SERVER/src/application/admin" \
  "$SERVER/src/application/payment" \
  "eval/tasks/regression-64-audit-log-before-after.json" \
  2>/dev/null || true)

if [ -z "$EXT_HITS" ]; then
  echo "  ✓ [10/10] 외부 프로젝트 인용 0건 (admin + payment + regression-64)"
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
  echo "  ✗ FAIL — PAY-P2-4 회귀 검출 (commit 차단)"
  echo "  → 정본: reports/sprint-pay-p2-4-audit-strengthening-progress.md §2 AC-1~AC-7"
  exit 2
fi

echo "  ✓ PASS — PAY-P2-4 모든 검증 정합"
exit 0
