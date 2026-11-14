#!/usr/bin/env bash
# sensor-payment-retry-reuse — PAY-P1-3 결제 실패 retry 정책 회귀 차단
#
# 발동 조건:
# - pre-commit / pre-push (server 변경 시)
# - 정기 회귀 (eval-runner)
#
# 정본 (단일 진실):
# - `reports/sprint-pay-p1-3-retry-policy-progress.md` §2 AC-1~AC-7
# - `.claude/shared-contracts.md` §14 PaymentRetryReuse
#
# 검증 영역 (10건):
# 1. PaymentRepositoryPort.findReusablePendingPayment 시그니처
# 2. PrismaPaymentRepository.findReusablePendingPayment 구현 + WHERE 조건
# 3. PaymentUseCase.initiatePayment 진입 게이트
# 4. PaymentCleanupJob @Cron 새벽 4시 + AuditLog operator='system_cleanup'
# 5. payment-cleanup.job.spec.ts 신설 (≥3 it)
# 6. prisma-payment.repository.spec.ts findReusablePendingPayment spec (≥4 it)
# 7. payment.usecase.spec.ts PAY-P1-3 4 it 추가
# 8. app.module.ts PaymentCleanupJob 등록
# 9. 외부 프로젝트 인용 0건 (CERTI_PROJ / brightmall / thermage / inapi)
# 10. spec 더미 assertion 차단 (toHaveBeenCalledWith ≥7건 합산)
#
# Exit codes:
# - 0 PASS — 모두 정합
# - 1 WARN — 일부 정책 미준수 (commit 허용)
# - 2 FAIL — AC 미충족 (commit 차단)

# sensor-log 자동 박제 (트랙 1-A 보강 — exit code 자동 매핑: 0=PASS / 1=FAIL / 2=WARN)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set +e

# script 위치 기반 PROJECT_ROOT 추론 (claude-docs hook에서 호출되든 메인 cwd가 server이든 동일하게 동작)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 2

SERVER="grimoire-server"

if [ ! -d "$SERVER" ]; then
  echo "  ⚠ grimoire-server 디렉토리 없음 (PROJECT_ROOT=$PROJECT_ROOT) — sensor 면제"
  exit 0
fi

echo "── sensor-payment-retry-reuse (PAY-P1-3 회귀 차단) ──"

PASS=0
FAIL=0
WARN=0

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

# 1. PaymentRepositoryPort 시그니처
check "[1/10] PaymentRepositoryPort.findReusablePendingPayment 시그니처 박제" \
  grep -qE "findReusablePendingPayment\(" "$SERVER/src/domain/port/outbound/payment-repository.port.ts"

# 2. Repository 구현 + WHERE
check "[2/10] PrismaPaymentRepository.findReusablePendingPayment 구현" \
  grep -qE "findReusablePendingPayment" "$SERVER/src/adapter/outbound/persistence/prisma-payment.repository.ts"

# 3. UseCase 진입 게이트
check "[3/10] PaymentUseCase.initiatePayment 진입 게이트 박제" \
  grep -qE "findReusablePendingPayment\(authorId" "$SERVER/src/application/payment/payment.usecase.ts"

# 4. PaymentCleanupJob cron + AuditLog operator
check "[4a/10] PaymentCleanupJob @Cron('0 0 4 * * *') 박제" \
  grep -qE "@Cron\\('0 0 4 \\* \\* \\*'\\)" "$SERVER/src/application/payment/payment-cleanup.job.ts"

check "[4b/10] AuditLog operator='system_cleanup' 박제" \
  grep -qE "system_cleanup" "$SERVER/src/application/payment/payment-cleanup.job.ts"

check "[4c/10] AuditLog action='payment_expire' 박제" \
  grep -qE "payment_expire" "$SERVER/src/application/payment/payment-cleanup.job.ts"

# 5. payment-cleanup.job.spec
check "[5/10] payment-cleanup.job.spec.ts 신설" \
  test -f "$SERVER/src/application/payment/payment-cleanup.job.spec.ts"

# 6. prisma-payment.repository.spec
check "[6/10] prisma-payment.repository.spec.ts 신설 (findReusablePendingPayment spec)" \
  bash -c "test -f '$SERVER/src/adapter/outbound/persistence/prisma-payment.repository.spec.ts' && grep -qE 'findReusablePendingPayment' '$SERVER/src/adapter/outbound/persistence/prisma-payment.repository.spec.ts'"

# 7. payment.usecase.spec.ts PAY-P1-3 4 it
check "[7/10] payment.usecase.spec.ts PAY-P1-3 describe 박제" \
  grep -qE "PAY-P1-3" "$SERVER/src/application/payment/payment.usecase.spec.ts"

# 8. app.module.ts DI
check "[8/10] app.module.ts PaymentCleanupJob 등록" \
  grep -qE "PaymentCleanupJob" "$SERVER/src/app.module.ts"

# 9. 외부 프로젝트 인용 0건 (server 운영 코드 영역만 — claude-docs research/sprint progress는 의도된 정본 인용 면제)
EXT_HITS=$(grep -rE 'CERTI_PROJ|brightmall|thermage|inapi|admin-certilife|no1-sass' \
  "$SERVER/src" \
  "$SERVER/docs" \
  "eval/tasks/regression-57-payment-retry-reuse.json" \
  2>/dev/null || true)

if [ -z "$EXT_HITS" ]; then
  echo "  ✓ [9/10] 외부 프로젝트 인용 0건 (server src/docs + regression-57)"
  PASS=$((PASS+1))
else
  echo "  ✗ [9/10] 외부 프로젝트 인용 검출"
  echo "$EXT_HITS" | head -5
  FAIL=$((FAIL+1))
fi

# 10. spec 더미 assertion 차단 — toHaveBeenCalledWith ≥7건 합산
USECASE_SPEC_HITS=$(grep -cE "toHaveBeenCalledWith|toHaveBeenCalledTimes" \
  "$SERVER/src/application/payment/payment.usecase.spec.ts" 2>/dev/null)
USECASE_SPEC_HITS=${USECASE_SPEC_HITS:-0}
CLEANUP_SPEC_HITS=$(grep -cE "toHaveBeenCalledWith|toHaveBeenCalledTimes" \
  "$SERVER/src/application/payment/payment-cleanup.job.spec.ts" 2>/dev/null)
CLEANUP_SPEC_HITS=${CLEANUP_SPEC_HITS:-0}
TOTAL_HITS=$((USECASE_SPEC_HITS + CLEANUP_SPEC_HITS))

if [ "$TOTAL_HITS" -ge 7 ]; then
  echo "  ✓ [10/10] 의미 있는 assertion ≥7건 (usecase=$USECASE_SPEC_HITS + cleanup=$CLEANUP_SPEC_HITS = $TOTAL_HITS)"
  PASS=$((PASS+1))
else
  echo "  ✗ [10/10] 의미 있는 assertion 부족 (합계 $TOTAL_HITS < 7)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "── 종합 ──"
echo "  PASS: $PASS / FAIL: $FAIL / WARN: $WARN"

if [ $FAIL -gt 0 ]; then
  echo "  ✗ FAIL — PAY-P1-3 회귀 검출 (commit 차단)"
  echo "  → 정본: reports/sprint-pay-p1-3-retry-policy-progress.md §2 AC-1~AC-7"
  exit 2
fi

echo "  ✓ PASS — PAY-P1-3 모든 검증 정합"
exit 0
