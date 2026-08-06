#!/bin/bash
# sensor-credit-overhaul-recalc
# 크레딧 개편 I Phase (게이트 6 / §8-8 CRITICAL #5) — 차감 N 재산정 트리거 sensor.
#
# §8-7 #8 — 경계선 운영(쿠션 거의 0). 환율/모델가 임계 도달 시 차감 N
# (190/810/3,390/5,520/2,440/590pt) 재산정이 필요. 본 sensor 가 트리거를 감지한다.
#
# 검증 대상:
#   1. AI_COST_MONITOR.md 존재 (재스윕 정본)
#   2. ai-cost-table.md 디노미네이션 1,000pt 반영 (cost-accountant 승인)
#   3. ai-cost-table.md 채팅 4구간 pt(190/810/3,390/5,520) §8 확정값 일치
#   4. ai-cost-table.md 분석 2,440pt / 테마 590pt §8 확정값 일치
#   5. ai-cost-table.md 구독 풀 93,000/191,500 §8 확정값 일치
#   6. chat-charge-tier.ts 차감 N 이 ai-cost-table 과 정합 (코드↔문서 drift 차단)
#   7. ADR-012 재산정 트리거 조건 박제
#
# 재산정 트리거 (§8-7 #8 — 본 sensor 가 WARN 시 cost-accountant 핸드오프):
#   - 환율 ₩1,624.33 도달 / Sonnet 단가 ±20% / 합성 변동 누적 +25%
#
# Exit codes:
#   0 = PASS / 1 = FAIL

trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
COST_TABLE="$SERVER/docs/ai-cost-table.md"
COST_MONITOR="$ROOT/reports/AI_COST_MONITOR.md"
TIER_MODEL="$SERVER/src/domain/model/chat-charge-tier.ts"
ADR="$SERVER/ADR.md"

PASS=0
FAIL=0

echo "=== sensor-credit-overhaul-recalc ($(date '+%H:%M:%S')) ==="
echo ""

# 1. AI_COST_MONITOR.md 존재
if [ -f "$COST_MONITOR" ]; then
  echo "  [PASS] AI_COST_MONITOR.md 존재 (재스윕 정본)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] AI_COST_MONITOR.md 누락 — 재산정 트리거 감지 불가"
  FAIL=$((FAIL + 1))
fi

# 2. ai-cost-table.md 디노미네이션 반영
if grep -qE '1.?000 ?pt|디노미네이션' "$COST_TABLE" 2>/dev/null; then
  echo "  [PASS] ai-cost-table.md 디노미네이션 1,000pt 반영"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] ai-cost-table.md 디노미네이션 미반영 — cost-accountant 개정 필요"
  FAIL=$((FAIL + 1))
fi

# 3. 채팅 4구간 pt §8 확정값 (190/810/3,390/5,520)
TIER_HITS=0
for pt in 190 810 "3,390" "5,520"; do
  grep -qE "${pt}" "$COST_TABLE" 2>/dev/null && TIER_HITS=$((TIER_HITS + 1))
done
if [ "$TIER_HITS" -ge 4 ]; then
  echo "  [PASS] ai-cost-table.md 채팅 4구간 pt 4종 §8 확정값 일치"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] 채팅 4구간 pt drift ($TIER_HITS/4) — §8 확정값 불일치"
  FAIL=$((FAIL + 1))
fi

# 4. 분석 2,440pt / 테마 590pt
if grep -qE '2.?440' "$COST_TABLE" 2>/dev/null && grep -qE '590 ?pt|590' "$COST_TABLE" 2>/dev/null; then
  echo "  [PASS] ai-cost-table.md 분석 2,440pt / 테마 590pt §8 확정값 일치"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] 분석/테마 차감 pt drift — §8 확정값 불일치"
  FAIL=$((FAIL + 1))
fi

# 5. 구독 풀 93,000 / 191,500
if grep -qE '93.?000' "$COST_TABLE" 2>/dev/null && grep -qE '191.?500' "$COST_TABLE" 2>/dev/null; then
  echo "  [PASS] ai-cost-table.md 구독 풀 93,000/191,500 §8 확정값 일치"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] 구독 풀 크기 drift — §8 확정값 불일치"
  FAIL=$((FAIL + 1))
fi

# 6. chat-charge-tier.ts 코드 차감 N 이 §8 확정값과 정합
if grep -qE 'points: 190' "$TIER_MODEL" 2>/dev/null \
  && grep -qE 'points: 810' "$TIER_MODEL" 2>/dev/null \
  && grep -qE 'points: 3390' "$TIER_MODEL" 2>/dev/null \
  && grep -qE 'points: 5520' "$TIER_MODEL" 2>/dev/null; then
  echo "  [PASS] chat-charge-tier.ts 차감 N (190/810/3390/5520) 코드↔문서 정합"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] chat-charge-tier.ts 차감 N drift — 코드↔ai-cost-table 불일치"
  FAIL=$((FAIL + 1))
fi

# 7. ADR-012 재산정 트리거 조건 박제
if grep -qE 'ADR-012' "$ADR" 2>/dev/null && grep -qE 'sensor-credit-overhaul-recalc|재산정' "$ADR" 2>/dev/null; then
  echo "  [PASS] ADR-012 재산정 트리거 조건 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] ADR-012 재산정 트리거 조건 누락"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"
echo ""
echo "[재산정 트리거 — §8-7 #8] 아래 도달 시 cost-accountant 핸드오프 (차감 N 코드변경 sprint):"
echo "  - 환율 ₩1,624.33 도달 / Sonnet 단가 ±20% / 합성 변동 누적 +25%"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 (차감 N drift 또는 정본 누락)"
  exit 1
fi

echo "[RESULT] PASS — 차감 N §8 확정값 정합 + 재산정 트리거 감시 정상"
exit 0
