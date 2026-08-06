#!/bin/bash
# sensor-payment-reconciliation
# PAY-P0-2: NestJS @Cron 10분 PG↔DB 정합성 검증 패턴 검증.
# Constitution P16 (결제 원자성)와 함께 commit 직전 자동 차단.
#
# 검증 대상:
#   1. PaymentReconciliationJob 파일 존재
#   2. @Cron 데코레이터
#   3. ReconciliationCheckpoint Prisma 모델
#   4. PaymentGatewayPort.listRecentCheckouts 시그니처
#   5. AdminAuditLog operator='system_reconciliation'
#   6. 3 action 식별자 (boost/refund_mismatch/expire)
#   7. isRunning lock
#   8. spec 파일 존재 (4 시나리오)
#   9. ReconciliationCheckpointRepositoryPort 인터페이스
#   10. 마이그레이션 파일
#
# Exit codes:
#   0 = PASS / 1 = FAIL

# sensor-log 자동 박제 (트랙 1-A 보강 — exit code 자동 매핑: 0=PASS / 1=FAIL / 2=WARN)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
JOB="$SERVER/src/application/payment/payment-reconciliation.job.ts"
JOB_SPEC="$SERVER/src/application/payment/payment-reconciliation.job.spec.ts"
GATEWAY_PORT="$SERVER/src/domain/port/outbound/payment-gateway.port.ts"
CHECKPOINT_PORT="$SERVER/src/domain/port/outbound/reconciliation-checkpoint-repository.port.ts"
SCHEMA="$SERVER/prisma/schema.prisma"
MIG_DIR="$SERVER/prisma/migrations"

PASS=0
FAIL=0

echo "=== sensor-payment-reconciliation ($(date '+%H:%M:%S')) ==="
echo ""

# 1. job 파일 존재
if [ -f "$JOB" ]; then
  echo "  [PASS] PaymentReconciliationJob 파일 존재"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] payment-reconciliation.job.ts 누락"
  FAIL=$((FAIL + 1))
fi

# 2. @Cron 데코레이터
if grep -qE '@Cron\s*\(' "$JOB" 2>/dev/null; then
  echo "  [PASS] @Cron 데코레이터 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] @Cron 데코레이터 누락 — 자동 실행 부재"
  FAIL=$((FAIL + 1))
fi

# 3. ReconciliationCheckpoint Prisma 모델
if grep -qE 'model ReconciliationCheckpoint' "$SCHEMA" 2>/dev/null; then
  echo "  [PASS] ReconciliationCheckpoint Prisma 모델 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] ReconciliationCheckpoint 모델 누락"
  FAIL=$((FAIL + 1))
fi

# 4. PaymentGatewayPort.listRecentCheckouts
if grep -qE 'listRecentCheckouts' "$GATEWAY_PORT" 2>/dev/null; then
  echo "  [PASS] PaymentGatewayPort.listRecentCheckouts 시그니처 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] listRecentCheckouts 시그니처 누락 — Polar list API 추상화 부재"
  FAIL=$((FAIL + 1))
fi

# 5. AdminAuditLog operator='system_reconciliation'
if grep -qE "system_reconciliation" "$JOB" 2>/dev/null; then
  echo "  [PASS] AuditLog operator='system_reconciliation' 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] system_reconciliation operator 누락 — 자동 보정 추적 부재"
  FAIL=$((FAIL + 1))
fi

# 6. 3 action 식별자
ACTIONS=$(grep -cE 'reconciliation_boost|reconciliation_refund_mismatch|reconciliation_expire' "$JOB" 2>/dev/null); ACTIONS=${ACTIONS:-0}
if [ "$ACTIONS" -ge 3 ]; then
  echo "  [PASS] 3 action 식별자 박제 (boost/refund_mismatch/expire)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] 3 action 식별자 누락 ($ACTIONS/3)"
  FAIL=$((FAIL + 1))
fi

# 7. isRunning lock
if grep -qE 'isRunning' "$JOB" 2>/dev/null; then
  echo "  [PASS] isRunning lock 박제 (동시 cron 차단)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] isRunning lock 누락 — 동시 cron 실행 차단 부재"
  FAIL=$((FAIL + 1))
fi

# 8. spec 파일
if [ -f "$JOB_SPEC" ]; then
  echo "  [PASS] payment-reconciliation.job.spec.ts 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] spec 파일 누락"
  FAIL=$((FAIL + 1))
fi

# 9. ReconciliationCheckpointRepositoryPort
if [ -f "$CHECKPOINT_PORT" ]; then
  echo "  [PASS] ReconciliationCheckpointRepositoryPort 인터페이스 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] ReconciliationCheckpointRepositoryPort 누락"
  FAIL=$((FAIL + 1))
fi

# 10. 마이그레이션 파일
if ls "$MIG_DIR" 2>/dev/null | grep -q reconciliation_checkpoint; then
  echo "  [PASS] Prisma 마이그레이션 파일 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] reconciliation_checkpoint 마이그레이션 누락"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 누락 (PAY-P0-2 회귀)"
  exit 1
fi

echo "[RESULT] PASS — 정합성 cron 패턴 모두 박제"
exit 0
