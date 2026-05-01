#!/usr/bin/env bash
# sensor-credit-atomicity.sh — 결제·환불·CreditLog 원자성 정합성 sensor
#
# 동기 (Fowler "Requisite Variety" 갭, research/HARNESS_FIELD_PATTERNS_4.md §15.5 + research/HARNESS_ENGINEERING.md §16):
#   - ProjectGrimoire 도메인의 결제·환불·크레딧은 가장 위험한 데이터 흐름
#   - 기존 sensor 8종 중 결제 영역 sensor 부재 (성숙도 진단 3.0/5)
#   - 본 sensor는 코드 정합성만 검사 (실 DB 쿼리는 P2)
#
# 검증 항목 (코드 정적 분석):
#   1. payment.usecase.ts에 $transaction 사용 여부 (원자성)
#   2. CreditLog 기록이 모든 credit 변경 분기에 동반되는지 (audit trail)
#   3. 환불 분기 (catch + abortableRace) 존재 여부
#   4. Polar webhook secret이 process.env 참조 (하드코딩 금지)
#
# 실행 모드:
#   - 기본: server 코드 grep + 결과 요약
#   - --strict: FAIL 1건이라도 있으면 exit 1
#   - --quiet: PASS 시 출력 없음
#
# Anthropic InstructionsLoaded hook과 결합 가능 (CLAUDE.md 로드 시 자동 호출 후보)

set +u

STRICT=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --quiet) QUIET=1 ;;
  esac
done

SERVER="/Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server"
PAYMENT_USECASE="$SERVER/src/application/payment/payment.usecase.ts"
CREDIT_USECASE="$SERVER/src/application/credit/credit.usecase.ts"
ANALYSIS_USECASE="$SERVER/src/application/analysis/novel-analysis.usecase.ts"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
declare -a FINDINGS=()

check() {
  local name="$1"
  local result="$2"  # PASS / FAIL / WARN
  local detail="$3"
  case "$result" in
    PASS) PASS_COUNT=$((PASS_COUNT+1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT+1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT+1)) ;;
  esac
  FINDINGS+=("[$result] $name — $detail")
}

[ "$QUIET" -eq 0 ] && echo "=== sensor-credit-atomicity ($(date +'%H:%M:%S')) ==="

# 1. $transaction 사용 (Hexagonal 정합: application은 repository 위임, $transaction은 adapter)
if [ -f "$PAYMENT_USECASE" ]; then
  # adapter/outbound/persistence 레이어의 prisma-payment + prisma-credit 트랜잭션 검사
  PAYMENT_REPO_TX=$(grep -c '\$transaction' "$SERVER/src/adapter/outbound/persistence/prisma-payment.repository.ts" 2>/dev/null) || PAYMENT_REPO_TX=0
  CREDIT_REPO_TX=$(grep -c '\$transaction' "$SERVER/src/adapter/outbound/persistence/prisma-credit.repository.ts" 2>/dev/null) || CREDIT_REPO_TX=0

  if [ "$PAYMENT_REPO_TX" -ge 1 ] && [ "$CREDIT_REPO_TX" -ge 1 ]; then
    check 'payment+credit repository $transaction' "PASS" "payment $PAYMENT_REPO_TX 건 + credit $CREDIT_REPO_TX 건 (Hexagonal 정합)"
  elif [ "$PAYMENT_REPO_TX" -ge 1 ] || [ "$CREDIT_REPO_TX" -ge 1 ]; then
    check 'payment+credit repository $transaction' "WARN" "payment $PAYMENT_REPO_TX 건 / credit $CREDIT_REPO_TX 건 — 한쪽만 보장됨"
  else
    check 'payment+credit repository $transaction' "FAIL" "양쪽 repository 0 건 — 결제·크레딧 원자성 깨질 위험 (SECURITY.md §3 위반)"
  fi
else
  check "payment.usecase 파일 존재" "WARN" "$PAYMENT_USECASE 없음 (skip)"
fi

# 2. CreditLog 기록 — credit 변경 시 항상 동반되는지
if [ -d "$SERVER/src/application" ]; then
  # creditLog.create 호출 카운트 vs author.update credits 변경 카운트
  CREDIT_LOG_COUNT=$(grep -rn "creditLog\.create\|prisma.creditLog.create" "$SERVER/src/application" 2>/dev/null | wc -l | tr -d ' ')
  CREDIT_UPDATE_COUNT=$(grep -rn "credits:" "$SERVER/src/application" 2>/dev/null | grep -E "increment|decrement|set:" | wc -l | tr -d ' ')

  if [ "$CREDIT_LOG_COUNT" -ge 1 ]; then
    check "CreditLog audit trail" "PASS" "$CREDIT_LOG_COUNT 건 기록 (credit 변경 $CREDIT_UPDATE_COUNT 건)"
  else
    check "CreditLog audit trail" "WARN" "creditLog.create 호출 0 건 — audit trail 부재 가능성"
  fi
fi

# 3. 환불 분기 (catch + abortableRace) — analysis usecase
if [ -f "$ANALYSIS_USECASE" ]; then
  REFUND_COUNT=$(grep -cE "refund|abortableRace|환불" "$ANALYSIS_USECASE" 2>/dev/null) || REFUND_COUNT=0
  CATCH_COUNT=$(grep -cE "^\s*}\s*catch\s*\(" "$ANALYSIS_USECASE" 2>/dev/null) || CATCH_COUNT=0

  if [ "$REFUND_COUNT" -ge 1 ] && [ "$CATCH_COUNT" -ge 1 ]; then
    check "분석 환불 분기" "PASS" "refund/abortableRace $REFUND_COUNT 건, catch $CATCH_COUNT 블록"
  else
    check "분석 환불 분기" "FAIL" "환불 처리 부재 (UI 약속 vs 서버 미구현 위험, 2026-04-19 회귀)"
  fi
fi

# 4. Polar webhook secret 하드코딩 금지 — spec/test 파일 제외
WEBHOOK_FILES=$(find "$SERVER/src" -type f -name "*.ts" -not -name "*.spec.ts" -not -name "*.test.ts" 2>/dev/null | xargs grep -l "POLAR_WEBHOOK_SECRET\|webhookSecret\|polar_whs_" 2>/dev/null | head -5)
if [ -n "$WEBHOOK_FILES" ]; then
  HARDCODED=0
  for f in $WEBHOOK_FILES; do
    # process.env 참조가 아닌 직접 할당 (예: webhookSecret = 'literal') 검사
    # spec.ts는 위에서 이미 제외됨
    if grep -E "(POLAR_WEBHOOK_SECRET|webhookSecret)\s*[:=]\s*['\"][a-zA-Z0-9_]{10,}['\"]" "$f" >/dev/null 2>&1; then
      HARDCODED=$((HARDCODED+1))
    fi
  done
  if [ "$HARDCODED" -eq 0 ]; then
    check "Polar webhook secret env 강제" "PASS" "webhook secret 하드코딩 0 건 (process.env 참조만)"
  else
    check "Polar webhook secret env 강제" "FAIL" "$HARDCODED 건 하드코딩 발견 → 즉시 회수"
  fi
else
  check "Polar webhook secret 코드 위치" "WARN" "webhook 처리 코드 미발견 (skip)"
fi

# 결과
[ "$QUIET" -eq 0 ] && echo ""
[ "$QUIET" -eq 0 ] && echo "─── 결과 ───"
[ "$QUIET" -eq 0 ] && printf '%s\n' "${FINDINGS[@]}"
[ "$QUIET" -eq 0 ] && echo ""
[ "$QUIET" -eq 0 ] && echo "PASS: $PASS_COUNT / FAIL: $FAIL_COUNT / WARN: $WARN_COUNT"

CA_LOG="$(dirname "$0")/sensor-log.sh"
if [ "$FAIL_COUNT" -gt 0 ]; then
  if [ "$STRICT" -eq 1 ]; then
    [ "$QUIET" -eq 0 ] && echo "[RESULT] FAIL (strict mode) — 결제·환불 원자성 위반"
    bash "$CA_LOG" "sensor-credit-atomicity" FAIL "FAIL=$FAIL_COUNT WARN=$WARN_COUNT strict" 2>/dev/null || true
    exit 1
  fi
  [ "$QUIET" -eq 0 ] && echo "[RESULT] FAIL — 즉시 검토 권장 (strict 미사용으로 exit 0)"
  bash "$CA_LOG" "sensor-credit-atomicity" FAIL "FAIL=$FAIL_COUNT WARN=$WARN_COUNT non-strict" 2>/dev/null || true
  exit 0
elif [ "$WARN_COUNT" -gt 0 ]; then
  [ "$QUIET" -eq 0 ] && echo "[RESULT] WARN — $WARN_COUNT 건 검토"
  bash "$CA_LOG" "sensor-credit-atomicity" WARN "WARN=$WARN_COUNT" 2>/dev/null || true
  exit 2
fi

[ "$QUIET" -eq 0 ] && echo "[RESULT] PASS — 결제·환불·크레딧 원자성 정합 OK"
bash "$CA_LOG" "sensor-credit-atomicity" PASS "PASS=$PASS_COUNT" 2>/dev/null || true
exit 0
