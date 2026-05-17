#!/bin/bash
# sensor-chat-charge-tier
# 크레딧 개편 I Phase (게이트 5 / §8-8 CRITICAL #4) — 채팅 4구간 차감 정합 검증.
#
# §8-8 #4 — 채팅 초장문 4구간 분리 필수. 3구간 시 P99 꼬리 2.40× §0 위반.
# §8-8 #3 — 채팅 토큰 실측 필드(ChatMessage.inputTokens 등) 선행 필수.
#
# 검증 대상:
#   1. chat-charge-tier.ts CHAT_CHARGE_TIERS — 정확히 4구간 (short/normal/long/xlong)
#   2. 차감 N §8 확정값 (190/810/3390/5520) — 재산출 금지
#   3. xlong 구간 inputMax Infinity (초장문 분리 — 3구간 회귀 차단)
#   4. schema.prisma ChatMessage 토큰 필드 5종 (inputTokens/outputTokens/model/chargedPoints/chargeTier)
#   5. ChatMessage 토큰 필드 nullable (§8-8 #3 — "0 토큰" vs "미측정" 구분)
#   6. claude-api.port.ts askWithUsage 시그니처 (토큰 usage 노출)
#   7. chat.usecase.ts 사후 차감 연동 (chargeChatTurn)
#   8. credit-system-setting.ts SystemSetting 동적 경계값 (loadChatChargeTiers)
#   9. charge-points.usecase.ts 가 inputTokens 검증 (음수 차단)
#
# Exit codes:
#   0 = PASS / 1 = FAIL

trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
SCHEMA="$SERVER/prisma/schema.prisma"
TIER_MODEL="$SERVER/src/domain/model/chat-charge-tier.ts"
SETTING_MODEL="$SERVER/src/domain/model/credit-system-setting.ts"
CLAUDE_PORT="$SERVER/src/domain/port/outbound/claude-api.port.ts"
CHAT_UC="$SERVER/src/application/chat/chat.usecase.ts"
CHARGE_UC="$SERVER/src/application/credit/charge-points.usecase.ts"

PASS=0
FAIL=0

echo "=== sensor-chat-charge-tier ($(date '+%H:%M:%S')) ==="
echo ""

# 1. CHAT_CHARGE_TIERS 정확히 4구간 — short/normal/long/xlong
TIER_COUNT=$(grep -cE "tier: '(short|normal|long|xlong)'" "$TIER_MODEL" 2>/dev/null || echo 0)
if [ "$TIER_COUNT" -eq 4 ] \
  && grep -qE "tier: 'xlong'" "$TIER_MODEL" 2>/dev/null; then
  echo "  [PASS] CHAT_CHARGE_TIERS 정확히 4구간 (short/normal/long/xlong)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] 채팅 구간이 4개가 아님 ($TIER_COUNT) — 3구간 시 §8-8 #4 위반"
  FAIL=$((FAIL + 1))
fi

# 2. 차감 N §8 확정값
if grep -qE 'points: 190' "$TIER_MODEL" 2>/dev/null \
  && grep -qE 'points: 810' "$TIER_MODEL" 2>/dev/null \
  && grep -qE 'points: 3390' "$TIER_MODEL" 2>/dev/null \
  && grep -qE 'points: 5520' "$TIER_MODEL" 2>/dev/null; then
  echo "  [PASS] 차감 N §8 확정값 (190/810/3390/5520) — 재산출 0건"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] 차감 N 이 §8 확정값과 불일치 (§8-8 #1 위반 — 재산출 금지)"
  FAIL=$((FAIL + 1))
fi

# 3. xlong inputMax Infinity (초장문 분리)
if grep -qE "tier: 'xlong'.*Infinity|Infinity.*xlong" "$TIER_MODEL" 2>/dev/null \
  || grep -A2 "tier: 'xlong'" "$TIER_MODEL" 2>/dev/null | grep -qE 'POSITIVE_INFINITY|Infinity'; then
  echo "  [PASS] xlong 구간 inputMax Infinity (초장문 분리 — 3구간 회귀 차단)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] xlong 구간 inputMax Infinity 누락 — 초장문 미분리"
  FAIL=$((FAIL + 1))
fi

# 4. ChatMessage 토큰 필드 5종
CM_BLOCK=$(sed -n '/model ChatMessage/,/^}/p' "$SCHEMA")
TOKEN_HITS=0
for f in 'inputTokens' 'outputTokens' 'model +String' 'chargedPoints' 'chargeTier'; do
  echo "$CM_BLOCK" | grep -qE "$f" && TOKEN_HITS=$((TOKEN_HITS + 1))
done
if [ "$TOKEN_HITS" -eq 5 ]; then
  echo "  [PASS] ChatMessage 토큰 필드 5종 (§8-8 #3 — 토큰 실측 선행)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] ChatMessage 토큰 필드 누락 ($TOKEN_HITS/5) — §8-8 #3 위반"
  FAIL=$((FAIL + 1))
fi

# 5. ChatMessage 토큰 필드 nullable
if echo "$CM_BLOCK" | grep -qE 'inputTokens +Int\?' \
  && echo "$CM_BLOCK" | grep -qE 'outputTokens +Int\?'; then
  echo "  [PASS] ChatMessage 토큰 필드 nullable ('0 토큰' vs '미측정' 구분)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] ChatMessage 토큰 필드 nullable 아님 — '미측정' 표현 불가"
  FAIL=$((FAIL + 1))
fi

# 6. claude-api.port.ts askWithUsage
if grep -qE 'askWithUsage' "$CLAUDE_PORT" 2>/dev/null; then
  echo "  [PASS] claude-api.port.ts askWithUsage 시그니처 (토큰 usage 노출)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] askWithUsage 누락 — 채팅 차감이 토큰 usage 미확보"
  FAIL=$((FAIL + 1))
fi

# 7. chat.usecase.ts 사후 차감 연동
if grep -qE 'chargeChatTurn' "$CHAT_UC" 2>/dev/null \
  && grep -qE 'askWithUsage' "$CHAT_UC" 2>/dev/null; then
  echo "  [PASS] chat.usecase.ts 사후 차감 연동 (chargeChatTurn + askWithUsage)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] chat.usecase.ts 사후 차감 미연동"
  FAIL=$((FAIL + 1))
fi

# 8. SystemSetting 동적 경계값
if [ -f "$SETTING_MODEL" ] && grep -qE 'loadChatChargeTiers' "$SETTING_MODEL" 2>/dev/null; then
  echo "  [PASS] credit-system-setting.ts SystemSetting 동적 경계값 (운영 재확정 대비)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] SystemSetting 동적 경계값 누락 — 재확정 시 재배포 필수"
  FAIL=$((FAIL + 1))
fi

# 9. charge-points.usecase.ts inputTokens 검증
if grep -qE 'inputTokens' "$CHARGE_UC" 2>/dev/null \
  && grep -qE 'BadRequestException' "$CHARGE_UC" 2>/dev/null; then
  echo "  [PASS] charge-points.usecase.ts inputTokens 검증 (음수/NaN 차단)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] charge-points.usecase.ts inputTokens 검증 누락"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 (채팅 4구간 차감 정합 누락)"
  exit 1
fi

echo "[RESULT] PASS — 채팅 4구간 사후 차감 정합 모두 박제 (3구간 회귀 차단)"
exit 0
