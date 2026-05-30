#!/bin/bash
# sensor-audit-retention-policy.sh
# PAY-P2-5 회귀 차단 — 4 모델 maskedAt + retentionTier 컬럼 + audit-mask-helper + audit-mask.job + migration + shared-contracts §26
#
# 정본: .claude/shared-contracts.md §26 AuditRetentionPolicy
# 사용자 결정 옵션 D (5/10): 영구 보존 + 90일 후 PII 마스킹 (DELETE 0건 강제)
#
# 검증 영역 (12건):
#   1. schema.prisma — 4 모델 maskedAt + retentionTier 컬럼 박제 (ALTER 4건)
#   2. schema.prisma — retention_tier @map 정합 (snake_case 박제)
#   3. migration.sql — ALTER TABLE 4 + ADD COLUMN 8 + CREATE INDEX 4 박제
#   4. audit-mask-helper.ts — PII 7 키 박제 + maskJsonDeep + maskAccessLogRow
#   5. audit-mask-helper.ts — PRESERVED_KEYS 매트릭스 박제 (audit 본질 보존)
#   6. audit-mask-helper.spec.ts — ≥18 it 박제
#   7. audit-mask.job.ts — @Cron('0 0 3 * * *') 박제 + AUDIT_MASK_DISABLED 게이트
#   8. audit-mask.job.ts — DELETE 호출 0건 강제 (영구 보존)
#   9. audit-mask.job.spec.ts — ≥6 it 박제
#  10. app.module.ts — AuditMaskJob providers 등록
#  11. shared-contracts.md §26 AuditRetentionPolicy 박제
#  12. ADR.md — ADR-008 박제 (영구 보존 + 마스킹 결정 사유)
#
# Exit codes:
#   0 = PASS / 1 = FAIL

# sensor-log 자동 박제
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
SCHEMA="$SERVER/prisma/schema.prisma"
MIGRATION="$SERVER/prisma/migrations/20260510_pay_p2_5_audit_retention_policy/migration.sql"
HELPER="$SERVER/src/adapter/outbound/persistence/audit-mask-helper.ts"
HELPER_SPEC="$SERVER/src/adapter/outbound/persistence/audit-mask-helper.spec.ts"
JOB="$SERVER/src/application/admin/audit-mask.job.ts"
JOB_SPEC="$SERVER/src/application/admin/audit-mask.job.spec.ts"
APP_MODULE="$SERVER/src/app.module.ts"
SHARED_CONTRACTS="$ROOT/.claude/shared-contracts.md"
ADR="$SERVER/ADR.md"

PASS=0
FAIL=0

echo "=== sensor-audit-retention-policy ($(date '+%H:%M:%S')) ==="
echo ""

# 1. schema.prisma 4 모델 maskedAt + retentionTier 박제 (정확히 4건)
MASKED_AT_COUNT=$(grep -cE "maskedAt\s+DateTime\?" "$SCHEMA" 2>/dev/null); MASKED_AT_COUNT=${MASKED_AT_COUNT:-0}
RETENTION_TIER_COUNT=$(grep -cE "retentionTier\s+String\s+@default\(\"active\"\)" "$SCHEMA" 2>/dev/null); RETENTION_TIER_COUNT=${RETENTION_TIER_COUNT:-0}
if [ "$MASKED_AT_COUNT" -eq 4 ] && [ "$RETENTION_TIER_COUNT" -eq 4 ]; then
  echo "  [PASS] schema.prisma: 4 모델 maskedAt(${MASKED_AT_COUNT}) + retentionTier(${RETENTION_TIER_COUNT}) 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] schema.prisma: maskedAt=${MASKED_AT_COUNT} retentionTier=${RETENTION_TIER_COUNT} (4건씩 정합 X)"
  FAIL=$((FAIL + 1))
fi

# 2. schema.prisma snake_case @map 정합
MAP_MASKED=$(grep -cE '@map\("masked_at"\)' "$SCHEMA" 2>/dev/null); MAP_MASKED=${MAP_MASKED:-0}
MAP_RETENTION=$(grep -cE '@map\("retention_tier"\)' "$SCHEMA" 2>/dev/null); MAP_RETENTION=${MAP_RETENTION:-0}
if [ "$MAP_MASKED" -eq 4 ] && [ "$MAP_RETENTION" -eq 4 ]; then
  echo "  [PASS] schema.prisma: snake_case @map 정합 (masked_at×${MAP_MASKED} retention_tier×${MAP_RETENTION})"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] schema.prisma: snake_case @map (masked_at=${MAP_MASKED} retention_tier=${MAP_RETENTION})"
  FAIL=$((FAIL + 1))
fi

# 3. migration.sql ALTER TABLE 4 + ADD COLUMN 8 + CREATE INDEX 4
if [ -f "$MIGRATION" ]; then
  ALTER_COUNT=$(grep -cE "^ALTER TABLE" "$MIGRATION" 2>/dev/null); ALTER_COUNT=${ALTER_COUNT:-0}
  ADD_COLUMN_COUNT=$(grep -cE "^\s*ADD COLUMN" "$MIGRATION" 2>/dev/null); ADD_COLUMN_COUNT=${ADD_COLUMN_COUNT:-0}
  CREATE_INDEX_COUNT=$(grep -cE "^CREATE INDEX" "$MIGRATION" 2>/dev/null); CREATE_INDEX_COUNT=${CREATE_INDEX_COUNT:-0}
  if [ "$ALTER_COUNT" -eq 4 ] && [ "$ADD_COLUMN_COUNT" -eq 8 ] && [ "$CREATE_INDEX_COUNT" -eq 4 ]; then
    echo "  [PASS] migration.sql: ALTER(${ALTER_COUNT}) + ADD COLUMN(${ADD_COLUMN_COUNT}) + CREATE INDEX(${CREATE_INDEX_COUNT})"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] migration.sql: ALTER=${ALTER_COUNT} ADD COLUMN=${ADD_COLUMN_COUNT} INDEX=${CREATE_INDEX_COUNT}"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [FAIL] migration.sql 미박제"
  FAIL=$((FAIL + 1))
fi

# 4. audit-mask-helper.ts PII 7 키 + maskJsonDeep + maskAccessLogRow
if [ -f "$HELPER" ]; then
  PII_OK=$(grep -cE "^\s*'(email|phone|ipAddress|userAgent|passwordHash|token|secret)'" "$HELPER" 2>/dev/null); PII_OK=${PII_OK:-0}
  HAS_DEEP=$(grep -cE "^export function maskJsonDeep" "$HELPER" 2>/dev/null); HAS_DEEP=${HAS_DEEP:-0}
  HAS_ACCESS=$(grep -cE "^export function maskAccessLogRow" "$HELPER" 2>/dev/null); HAS_ACCESS=${HAS_ACCESS:-0}
  if [ "$PII_OK" -ge 7 ] && [ "$HAS_DEEP" -ge 1 ] && [ "$HAS_ACCESS" -ge 1 ]; then
    echo "  [PASS] audit-mask-helper.ts: PII 7 키 + maskJsonDeep + maskAccessLogRow"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] audit-mask-helper.ts: PII=${PII_OK} deep=${HAS_DEEP} access=${HAS_ACCESS}"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [FAIL] audit-mask-helper.ts 미박제"
  FAIL=$((FAIL + 1))
fi

# 5. audit-mask-helper.ts PRESERVED_KEYS 매트릭스 (audit 본질 보존)
if [ -f "$HELPER" ]; then
  HAS_PRESERVED=$(grep -cE "^export const PRESERVED_KEYS" "$HELPER" 2>/dev/null); HAS_PRESERVED=${HAS_PRESERVED:-0}
  HAS_AUTHOR_ID=$(grep -cE "'authorId'" "$HELPER" 2>/dev/null); HAS_AUTHOR_ID=${HAS_AUTHOR_ID:-0}
  HAS_ADMIN_ID=$(grep -cE "'adminId'" "$HELPER" 2>/dev/null); HAS_ADMIN_ID=${HAS_ADMIN_ID:-0}
  if [ "$HAS_PRESERVED" -ge 1 ] && [ "$HAS_AUTHOR_ID" -ge 1 ] && [ "$HAS_ADMIN_ID" -ge 1 ]; then
    echo "  [PASS] audit-mask-helper.ts: PRESERVED_KEYS + authorId/adminId 박제"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] audit-mask-helper.ts: PRESERVED=${HAS_PRESERVED} authorId=${HAS_AUTHOR_ID} adminId=${HAS_ADMIN_ID}"
    FAIL=$((FAIL + 1))
  fi
fi

# 6. audit-mask-helper.spec.ts ≥18 it
if [ -f "$HELPER_SPEC" ]; then
  IT_COUNT=$(grep -cE "^\s*it\(" "$HELPER_SPEC" 2>/dev/null); IT_COUNT=${IT_COUNT:-0}
  if [ "$IT_COUNT" -ge 18 ]; then
    echo "  [PASS] audit-mask-helper.spec.ts: ${IT_COUNT} it (≥18 정합)"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] audit-mask-helper.spec.ts: ${IT_COUNT} it (18 미만)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [FAIL] audit-mask-helper.spec.ts 미박제"
  FAIL=$((FAIL + 1))
fi

# 7. audit-mask.job.ts @Cron + AUDIT_MASK_DISABLED 게이트
if [ -f "$JOB" ]; then
  HAS_CRON=$(grep -cE "@Cron\('0 0 3 \* \* \*'\)" "$JOB" 2>/dev/null); HAS_CRON=${HAS_CRON:-0}
  HAS_DISABLE=$(grep -cE "AUDIT_MASK_DISABLED" "$JOB" 2>/dev/null); HAS_DISABLE=${HAS_DISABLE:-0}
  if [ "$HAS_CRON" -ge 1 ] && [ "$HAS_DISABLE" -ge 1 ]; then
    echo "  [PASS] audit-mask.job.ts: @Cron 03:00 KST + AUDIT_MASK_DISABLED 게이트"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] audit-mask.job.ts: cron=${HAS_CRON} disable=${HAS_DISABLE}"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [FAIL] audit-mask.job.ts 미박제"
  FAIL=$((FAIL + 1))
fi

# 8. audit-mask.job.ts DELETE 호출 0건 강제 (영구 보존, 사용자 옵션 D 정합)
if [ -f "$JOB" ]; then
  DELETE_COUNT=$(grep -E "(\.delete\(|\.deleteMany\(|DELETE FROM)" "$JOB" 2>/dev/null | wc -l | tr -d ' ')
  DELETE_COUNT=${DELETE_COUNT:-0}
  if [ "$DELETE_COUNT" -eq 0 ]; then
    echo "  [PASS] audit-mask.job.ts: DELETE 호출 0건 (영구 보존 강제)"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] audit-mask.job.ts: DELETE 호출 ${DELETE_COUNT}건 — 사용자 옵션 D (영구 보존) 위반"
    FAIL=$((FAIL + 1))
  fi
fi

# 9. audit-mask.job.spec.ts ≥6 it
if [ -f "$JOB_SPEC" ]; then
  IT_COUNT=$(grep -cE "^\s*it\(" "$JOB_SPEC" 2>/dev/null); IT_COUNT=${IT_COUNT:-0}
  if [ "$IT_COUNT" -ge 6 ]; then
    echo "  [PASS] audit-mask.job.spec.ts: ${IT_COUNT} it (≥6 정합)"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] audit-mask.job.spec.ts: ${IT_COUNT} it (6 미만)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [FAIL] audit-mask.job.spec.ts 미박제"
  FAIL=$((FAIL + 1))
fi

# 10. app.module.ts AuditMaskJob providers 등록
HAS_IMPORT=$(grep -cE "import \{ AuditMaskJob \}" "$APP_MODULE" 2>/dev/null); HAS_IMPORT=${HAS_IMPORT:-0}
HAS_PROVIDER=$(grep -cE "AuditMaskJob," "$APP_MODULE" 2>/dev/null); HAS_PROVIDER=${HAS_PROVIDER:-0}
if [ "$HAS_IMPORT" -ge 1 ] && [ "$HAS_PROVIDER" -ge 1 ]; then
  echo "  [PASS] app.module.ts: AuditMaskJob import + providers"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] app.module.ts: import=${HAS_IMPORT} provider=${HAS_PROVIDER}"
  FAIL=$((FAIL + 1))
fi

# 11. shared-contracts.md §26 AuditRetentionPolicy
HAS_CONTRACT=$(grep -cE "^## 26\. AuditRetentionPolicy" "$SHARED_CONTRACTS" 2>/dev/null); HAS_CONTRACT=${HAS_CONTRACT:-0}
if [ "$HAS_CONTRACT" -ge 1 ]; then
  echo "  [PASS] shared-contracts.md §26 AuditRetentionPolicy 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] shared-contracts.md §26 미박제"
  FAIL=$((FAIL + 1))
fi

# 12. ADR.md ADR-008 박제
HAS_ADR=$(grep -cE "^## ADR-008" "$ADR" 2>/dev/null); HAS_ADR=${HAS_ADR:-0}
if [ "$HAS_ADR" -ge 1 ]; then
  echo "  [PASS] ADR.md ADR-008 박제 (영구 보존 + 마스킹 결정 사유)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] ADR.md ADR-008 미박제"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "── 종합 ──"
echo "  PASS: $PASS / FAIL: $FAIL (총 $((PASS + FAIL)))"

if [ "$FAIL" -gt 0 ]; then
  echo "❌ FAIL: PAY-P2-5 회귀 차단 영역 결함"
  exit 1
fi

echo "✅ PAY-P2-5 audit retention 정책 정합"
exit 0
