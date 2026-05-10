#!/bin/bash
# sensor-fk-cascade-policy.sh
# PAY-P3-E 회귀 차단 — Prisma schema 33 FK 영역 onDelete 박제 + 25 raw FK @relation 박제 + migration.sql + spec + shared-contracts §25 + data-model.md grep
#
# 정본: .claude/shared-contracts.md §25 FKCascadePolicy
#
# 검증 영역 (10건, Sprint §5-3 정합 ≥ 8 검증):
#   1. schema.prisma — onDelete directive 33건 박제 (PAYMENT_AUDIT §1 모순-F 차단)
#   2. schema.prisma — Cascade 16건 박제 (사용자 종속 + Work/Episode 종속 + 통계)
#   3. schema.prisma — Restrict 핵심 8건 박제 (회계/세무/감사 영구 보존)
#   4. schema.prisma — SetNull 핵심 영역 박제 (익명화 + 운영자 변경 보존)
#   5. schema.prisma — self-ref @relation name 4건 박제 (Subscriber/TargetAuthor/SanctionedAuthor/SanctioningAdmin/Reporter/Resolver/FeaturedWorkAdmin)
#   6. migration.sql — ALTER TABLE 영역 박제 (DROP NOT NULL 2 + DROP/ADD CONSTRAINT 영역)
#   7. prisma-fk-cascade.spec.ts — 8 it 박제 (Sprint §5-1 ≥ 6 it 정합)
#   8. shared-contracts.md §25 FKCascadePolicy 박제
#   9. data-model.md — onDelete 정책 박제 영역 (관계 다이어그램 영역)
#  10. ADR.md — ADR-007 박제 (4 전략 결정 사유)
#
# Exit codes:
#   0 = PASS / 1 = FAIL

# sensor-log 자동 박제 (트랙 1-A 정합)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
SCHEMA="$SERVER/prisma/schema.prisma"
MIGRATION="$SERVER/prisma/migrations/20260510_pay_p3_e_fk_cascade_policy/migration.sql"
SPEC="$SERVER/src/adapter/outbound/persistence/prisma-fk-cascade.spec.ts"
SHARED_CONTRACTS="$ROOT/.claude/shared-contracts.md"
DATA_MODEL="$SERVER/docs/data-model.md"
ADR="$SERVER/ADR.md"

PASS=0
FAIL=0

echo "=== sensor-fk-cascade-policy ($(date '+%H:%M:%S')) ==="
echo ""

# 1. schema.prisma onDelete directive 33건 박제 (33 FK 영역 정합)
ONDELETE_COUNT=$(grep -cE "onDelete:" "$SCHEMA" 2>/dev/null || echo 0)
if [ "$ONDELETE_COUNT" -ge 33 ]; then
  echo "  [PASS] schema.prisma: onDelete directive ${ONDELETE_COUNT}건 박제 (≥ 33 정합, PAYMENT_AUDIT §1 모순-F 차단)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] schema.prisma: onDelete directive ${ONDELETE_COUNT}건 (33 미만, 모순-F 회귀)"
  FAIL=$((FAIL + 1))
fi

# 2. Cascade 16건 박제 (사용자 종속 + Work/Episode 종속 + 통계)
CASCADE_COUNT=$(grep -cE "onDelete: Cascade" "$SCHEMA" 2>/dev/null || echo 0)
if [ "$CASCADE_COUNT" -ge 16 ]; then
  echo "  [PASS] schema.prisma: onDelete Cascade ${CASCADE_COUNT}건 박제 (≥ 16 정합)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] schema.prisma: onDelete Cascade ${CASCADE_COUNT}건 (16 미만, Cascade 영역 회귀)"
  FAIL=$((FAIL + 1))
fi

# 3. Restrict 핵심 8건 박제 (회계/세무/감사 영구 보존)
# 정본 매트릭스 (shared-contracts §25): Work / CreditLog / Payment / UserSanction.author / AnalysisReport / AdminAuditLog / RefundLog
RESTRICT_OK=1
declare -a RESTRICT_PATTERNS=(
  "Work.*authorId.*onDelete: Restrict"
  "CreditLog|credit_logs"
  "Payment|payments"
  "UserSanction|user_sanctions"
  "AnalysisReport|analysis_reports"
  "AdminAuditLog|admin_audit_logs"
  "RefundLog|refund_logs"
)
RESTRICT_TOTAL=$(grep -cE "onDelete: Restrict" "$SCHEMA" 2>/dev/null || echo 0)
if [ "$RESTRICT_TOTAL" -ge 7 ]; then
  echo "  [PASS] schema.prisma: onDelete Restrict ${RESTRICT_TOTAL}건 박제 (≥ 7 정합, 회계/세무/감사 영구 보존)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] schema.prisma: onDelete Restrict ${RESTRICT_TOTAL}건 (7 미만, 회계 영구 보존 회귀)"
  FAIL=$((FAIL + 1))
fi

# 4. SetNull 영역 박제 (익명화 + 운영자 변경 보존)
SETNULL_COUNT=$(grep -cE "onDelete: SetNull" "$SCHEMA" 2>/dev/null || echo 0)
if [ "$SETNULL_COUNT" -ge 9 ]; then
  echo "  [PASS] schema.prisma: onDelete SetNull ${SETNULL_COUNT}건 박제 (≥ 9 정합, 익명화 + 운영자 변경 보존)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] schema.prisma: onDelete SetNull ${SETNULL_COUNT}건 (9 미만, 익명화 영역 회귀)"
  FAIL=$((FAIL + 1))
fi

# 5. self-ref @relation name 4건 박제
RELATION_NAMES_OK=1
for rel_name in "Subscriber" "TargetAuthor" "SanctionedAuthor" "SanctioningAdmin" "Reporter" "Resolver" "FeaturedWorkAdmin"; do
  if ! grep -qE "@relation\(\"${rel_name}\"" "$SCHEMA" 2>/dev/null; then
    echo "  [FAIL] schema.prisma: @relation name '${rel_name}' 박제 0건 (self-ref 영역 회귀)"
    RELATION_NAMES_OK=0
    FAIL=$((FAIL + 1))
  fi
done
if [ "$RELATION_NAMES_OK" = "1" ]; then
  echo "  [PASS] schema.prisma: self-ref @relation name 7건 박제 (Subscriber/TargetAuthor/SanctionedAuthor/SanctioningAdmin/Reporter/Resolver/FeaturedWorkAdmin)"
  PASS=$((PASS + 1))
fi

# 6. migration.sql ALTER TABLE 영역 박제
if [ -f "$MIGRATION" ]; then
  ALTER_COUNT=$(grep -cE "^ALTER TABLE" "$MIGRATION" 2>/dev/null || echo 0)
  DROP_NOT_NULL_COUNT=$(grep -cE "DROP NOT NULL" "$MIGRATION" 2>/dev/null || echo 0)
  if [ "$ALTER_COUNT" -ge 33 ] && [ "$DROP_NOT_NULL_COUNT" -ge 2 ]; then
    echo "  [PASS] migration.sql: ALTER TABLE ${ALTER_COUNT}건 + DROP NOT NULL ${DROP_NOT_NULL_COUNT}건 박제 (≥ 33 + 2 정합)"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] migration.sql: ALTER TABLE ${ALTER_COUNT} (≥ 33 필요) / DROP NOT NULL ${DROP_NOT_NULL_COUNT} (≥ 2 필요)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [FAIL] migration.sql: 파일 박제 0건 — prisma/migrations/20260510_pay_p3_e_fk_cascade_policy/migration.sql 누락"
  FAIL=$((FAIL + 1))
fi

# 7. prisma-fk-cascade.spec.ts 8 it 박제 (Sprint §5-1 ≥ 6 it 정합)
if [ -f "$SPEC" ]; then
  IT_COUNT=$(grep -cE "^\s*it\(" "$SPEC" 2>/dev/null || echo 0)
  if [ "$IT_COUNT" -ge 6 ]; then
    echo "  [PASS] prisma-fk-cascade.spec.ts: ${IT_COUNT} it 박제 (≥ 6 정합, Sprint §5-1)"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] prisma-fk-cascade.spec.ts: ${IT_COUNT} it (≥ 6 필요)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [FAIL] prisma-fk-cascade.spec.ts: 파일 박제 0건"
  FAIL=$((FAIL + 1))
fi

# 8. shared-contracts §25 FKCascadePolicy 박제
if grep -qE "## 25\. FKCascadePolicy" "$SHARED_CONTRACTS" 2>/dev/null; then
  echo "  [PASS] shared-contracts §25 FKCascadePolicy 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] shared-contracts §25 FKCascadePolicy 누락 — 인터페이스 정본 부재"
  FAIL=$((FAIL + 1))
fi

# 9. data-model.md onDelete 정책 박제 영역
if [ -f "$DATA_MODEL" ] && grep -qE "onDelete|FK Cascade|PAY-P3-E|fk_cascade" "$DATA_MODEL" 2>/dev/null; then
  echo "  [PASS] data-model.md: onDelete 정책 박제 영역 (관계 다이어그램 정합)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] data-model.md: onDelete 정책 영역 박제 0건 — 관계 다이어그램 영역 회귀"
  FAIL=$((FAIL + 1))
fi

# 10. ADR.md ADR-007 박제 (4 전략 결정 사유)
if [ -f "$ADR" ] && grep -qE "ADR-007|fk.*cascade|FK Cascade|PAY-P3-E" "$ADR" 2>/dev/null; then
  echo "  [PASS] ADR.md: ADR-007 박제 (4 전략 결정 사유)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] ADR.md: ADR-007 박제 0건 — 4 전략 결정 영역 부재"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 누락 (PAY-P3-E FK Cascade 정책 회귀)"
  exit 1
fi

echo "[RESULT] PASS — FK Cascade 정책 (33 FK onDelete + 25 raw FK @relation + migration + spec + §25 + data-model + ADR-007) 모두 박제"
exit 0
