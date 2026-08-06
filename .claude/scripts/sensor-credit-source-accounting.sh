#!/bin/bash
# sensor-credit-source-accounting
# 크레딧 개편 I Phase (게이트 1) — 포인트 출처 4종 분리 회계 정합 검증.
#
# 검증 대상:
#   1. credit-source.ts CreditSource 4종 (free/subscription/gift/charged)
#   2. credit-source.ts CREDIT_CONSUMPTION_ORDER 소진 우선순위
#   3. schema.prisma CreditLedger 모델 신설
#   4. CreditLedger source/type 컬럼
#   5. CreditLedger.authorId FK Restrict (회계 영구 보존, ADR-007)
#   6. CreditLedger 인덱스 3종 ([authorId,createdAt] / [authorId,source] / [expiresAt])
#   7. credit-ledger.port.ts 포트 인터페이스 (earn/spend/getBalance/settleDeficit)
#   8. prisma-credit-ledger.repository.ts 어댑터
#   9. credit-consumption-policy.ts 소진 우선순위 정책
#   10. charge-points.usecase.ts + grant-points.usecase.ts
#
# Exit codes:
#   0 = PASS / 1 = FAIL

trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
SCHEMA="$SERVER/prisma/schema.prisma"
SOURCE_MODEL="$SERVER/src/domain/model/credit-source.ts"
LEDGER_PORT="$SERVER/src/domain/port/outbound/credit-ledger.port.ts"
LEDGER_ADAPTER="$SERVER/src/adapter/outbound/persistence/prisma-credit-ledger.repository.ts"
POLICY="$SERVER/src/domain/policy/credit-consumption-policy.ts"
CHARGE_UC="$SERVER/src/application/credit/charge-points.usecase.ts"
GRANT_UC="$SERVER/src/application/credit/grant-points.usecase.ts"

PASS=0
FAIL=0

echo "=== sensor-credit-source-accounting ($(date '+%H:%M:%S')) ==="
echo ""

# 1. CreditSource 4종
if grep -qE "'free' \| 'subscription' \| 'gift' \| 'charged'" "$SOURCE_MODEL" 2>/dev/null; then
  echo "  [PASS] credit-source.ts CreditSource 4종 (free/subscription/gift/charged)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] CreditSource 4종 정의 누락"
  FAIL=$((FAIL + 1))
fi

# 2. 소진 우선순위
if grep -qE "CREDIT_CONSUMPTION_ORDER" "$SOURCE_MODEL" 2>/dev/null \
  && grep -qE "'free'.*'subscription'.*'gift'.*'charged'" "$SOURCE_MODEL" 2>/dev/null; then
  echo "  [PASS] credit-source.ts 소진 우선순위 (무료적립→구독풀→응원선물→충전)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] CREDIT_CONSUMPTION_ORDER 소진 우선순위 누락"
  FAIL=$((FAIL + 1))
fi

# 3. CreditLedger 모델
if grep -qE 'model CreditLedger' "$SCHEMA" 2>/dev/null; then
  echo "  [PASS] schema.prisma CreditLedger 모델 신설"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] CreditLedger 모델 누락 — 입출금 원장 부재"
  FAIL=$((FAIL + 1))
fi

# 4. CreditLedger source/type 컬럼
if grep -qE 'model CreditLedger' "$SCHEMA" 2>/dev/null \
  && sed -n '/model CreditLedger/,/^}/p' "$SCHEMA" | grep -qE 'source +String' \
  && sed -n '/model CreditLedger/,/^}/p' "$SCHEMA" | grep -qE 'type +String'; then
  echo "  [PASS] CreditLedger source/type 컬럼 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] CreditLedger source/type 컬럼 누락"
  FAIL=$((FAIL + 1))
fi

# 5. CreditLedger.authorId FK Restrict
if grep -qE 'credit_ledgers_author_id_fkey.*RESTRICT' "$SERVER/prisma/migrations/20260517_credit_overhaul_i_phase/migration.sql" 2>/dev/null \
  || sed -n '/model CreditLedger/,/^}/p' "$SCHEMA" | grep -qE 'onDelete: Restrict'; then
  echo "  [PASS] CreditLedger.authorId FK Restrict (회계 영구 보존, ADR-007)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] CreditLedger.authorId FK Restrict 누락 — 회계 보존 미강제"
  FAIL=$((FAIL + 1))
fi

# 6. CreditLedger 인덱스 3종
LEDGER_BLOCK=$(sed -n '/model CreditLedger/,/^}/p' "$SCHEMA")
IDX_HITS=0
echo "$LEDGER_BLOCK" | grep -qE '@@index\(\[authorId, createdAt\]\)' && IDX_HITS=$((IDX_HITS + 1))
echo "$LEDGER_BLOCK" | grep -qE '@@index\(\[authorId, source\]\)' && IDX_HITS=$((IDX_HITS + 1))
echo "$LEDGER_BLOCK" | grep -qE '@@index\(\[expiresAt\]\)' && IDX_HITS=$((IDX_HITS + 1))
if [ "$IDX_HITS" -ge 3 ]; then
  echo "  [PASS] CreditLedger 인덱스 3종 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] CreditLedger 인덱스 누락 ($IDX_HITS/3)"
  FAIL=$((FAIL + 1))
fi

# 7. credit-ledger.port.ts
if [ -f "$LEDGER_PORT" ] \
  && grep -qE 'earn' "$LEDGER_PORT" 2>/dev/null \
  && grep -qE 'spend' "$LEDGER_PORT" 2>/dev/null \
  && grep -qE 'getBalance' "$LEDGER_PORT" 2>/dev/null \
  && grep -qE 'settleDeficit' "$LEDGER_PORT" 2>/dev/null; then
  echo "  [PASS] credit-ledger.port.ts 포트 (earn/spend/getBalance/settleDeficit)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] credit-ledger.port.ts 포트 시그니처 누락 — Hexagonal 추상화 부재"
  FAIL=$((FAIL + 1))
fi

# 8. prisma-credit-ledger.repository.ts
if [ -f "$LEDGER_ADAPTER" ]; then
  echo "  [PASS] prisma-credit-ledger.repository.ts 어댑터 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] prisma-credit-ledger.repository.ts 어댑터 누락"
  FAIL=$((FAIL + 1))
fi

# 9. credit-consumption-policy.ts
if [ -f "$POLICY" ] && grep -qE 'planConsumption' "$POLICY" 2>/dev/null; then
  echo "  [PASS] credit-consumption-policy.ts 소진 우선순위 정책 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] credit-consumption-policy.ts 정책 누락"
  FAIL=$((FAIL + 1))
fi

# 10. charge/grant usecase
if [ -f "$CHARGE_UC" ] && [ -f "$GRANT_UC" ]; then
  echo "  [PASS] charge-points.usecase.ts + grant-points.usecase.ts 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] charge/grant usecase 누락"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 (포인트 출처 회계 정합 누락)"
  exit 1
fi

echo "[RESULT] PASS — 포인트 출처 4종 분리 회계 정합 모두 박제"
exit 0
