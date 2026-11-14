#!/bin/bash
# sensor-credit-denomination
# 크레딧 개편 I Phase (게이트 2) — 디노미네이션 정합 검증.
#
# 검증 대상:
#   1. credit-point.ts 디노미네이션 상수 CREDIT_TO_POINT=1000
#   2. schema.prisma Author 4 필드 (pointsFree/pointsSubscription/pointsGift/pointsCharged)
#   3. schema.prisma Author.credits 부재 박제 (CC-4 Phase 3 — 2026-05-21 — DROP COLUMN 완료)
#   4. schema.prisma Author.deficitPoints 컬럼
#   5. migration.sql credits×1000 → points_charged 데이터 마이그레이션
#   6. AnalysisReport.creditsCharged default 2440 (디노미 정정)
#   7. chat-charge-tier.ts ANALYSIS_POINT_COST=2440 / THEME_POINT_COST=590
#   8. 마이그레이션 파일 존재
#
# Exit codes:
#   0 = PASS / 1 = FAIL

trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
SCHEMA="$SERVER/prisma/schema.prisma"
POINT_MODEL="$SERVER/src/domain/model/credit-point.ts"
TIER_MODEL="$SERVER/src/domain/model/chat-charge-tier.ts"
MIG="$SERVER/prisma/migrations/20260517_credit_overhaul_i_phase/migration.sql"

PASS=0
FAIL=0

echo "=== sensor-credit-denomination ($(date '+%H:%M:%S')) ==="
echo ""

# 1. CREDIT_TO_POINT=1000
if grep -qE 'CREDIT_TO_POINT *= *1000' "$POINT_MODEL" 2>/dev/null; then
  echo "  [PASS] credit-point.ts CREDIT_TO_POINT=1000 디노미네이션 상수"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] CREDIT_TO_POINT=1000 누락 — 디노미네이션 상수 부재"
  FAIL=$((FAIL + 1))
fi

# 2. Author 4 필드
FIELD_HITS=0
for f in points_free points_subscription points_gift points_charged; do
  grep -qE "$f" "$SCHEMA" 2>/dev/null && FIELD_HITS=$((FIELD_HITS + 1))
done
if [ "$FIELD_HITS" -eq 4 ]; then
  echo "  [PASS] schema.prisma Author 포인트 4 필드 박제 (출처 분리 회계)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Author 포인트 4 필드 누락 ($FIELD_HITS/4)"
  FAIL=$((FAIL + 1))
fi

# 3. CC-4 Phase 3 (2026-05-21) — Author.credits 컬럼 DROP 정합 박제
#    `model Author { ... }` 본문(첫 `model Author {` 부터 첫 `}` 직전까지) 안에 `credits Int` 패턴 부재 검증.
#    awk 로 model Author 블록만 추출 후 grep — RefundLog.credits / Payment(구) 등 다른 모델 영향 회피.
AUTHOR_BLOCK=$(awk '/^model Author \{/{p=1} p; /^\}/{if(p){p=0; exit}}' "$SCHEMA" 2>/dev/null)
if ! echo "$AUTHOR_BLOCK" | grep -qE '^[[:space:]]+credits[[:space:]]+Int'; then
  echo "  [PASS] schema.prisma model Author 본문에 credits 필드 부재 박제 (CC-4 Phase 3 DROP COLUMN 완료)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] model Author 안 credits 컬럼 잔존 — CC-4 Phase 3 마이그레이션 미적용 또는 schema.prisma 미갱신"
  FAIL=$((FAIL + 1))
fi

# 4. deficitPoints
if grep -qE 'deficit_points|deficitPoints' "$SCHEMA" 2>/dev/null; then
  echo "  [PASS] schema.prisma Author.deficitPoints 컬럼 박제 (외상)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] deficitPoints 컬럼 누락 — 외상 추적 불가"
  FAIL=$((FAIL + 1))
fi

# 5. migration.sql 데이터 마이그레이션
if [ -f "$MIG" ] && grep -qE 'points_charged.*=.*credits.*\* 1000|credits.*\* 1000' "$MIG" 2>/dev/null; then
  echo "  [PASS] migration.sql credits×1000 → points_charged 데이터 마이그레이션"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] migration.sql 디노미 환산 SQL 누락"
  FAIL=$((FAIL + 1))
fi

# 6. AnalysisReport.creditsCharged default 2440
if grep -qE 'creditsCharged Int +@default\(2440\)' "$SCHEMA" 2>/dev/null; then
  echo "  [PASS] AnalysisReport.creditsCharged default 2440 (디노미 정정)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] AnalysisReport.creditsCharged default 디노미 정정 누락"
  FAIL=$((FAIL + 1))
fi

# 7. ANALYSIS_POINT_COST / THEME_POINT_COST
if grep -qE 'ANALYSIS_POINT_COST *= *2440' "$TIER_MODEL" 2>/dev/null \
  && grep -qE 'THEME_POINT_COST *= *590' "$TIER_MODEL" 2>/dev/null; then
  echo "  [PASS] chat-charge-tier.ts ANALYSIS_POINT_COST=2440 / THEME_POINT_COST=590"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] 분석/테마 디노미 차감 상수 누락"
  FAIL=$((FAIL + 1))
fi

# 8. 마이그레이션 파일 존재
if [ -f "$MIG" ]; then
  echo "  [PASS] Prisma 마이그레이션 파일 박제 (20260517_credit_overhaul_i_phase)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] 크레딧 개편 마이그레이션 파일 누락"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 (디노미네이션 정합 누락)"
  exit 1
fi

echo "[RESULT] PASS — 디노미네이션 1,000pt 정합 모두 박제"
exit 0
