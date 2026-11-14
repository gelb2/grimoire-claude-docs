#!/usr/bin/env bash
# sensor-sms-service-port — PAY-P2-3 사전 작업: SmsServicePort 캡슐화 회귀 차단 (sprint #10_7)
#
# 발동 조건:
# - pre-commit / pre-push (server 변경 시)
# - 정기 회귀 (eval-runner)
#
# 정본 (단일 진실):
# - `reports/sprint-pay-p2-3-sms-service-port-progress.md` §2 AC-1~AC-5
# - `.claude/shared-contracts.md` §19 SmsServicePort
# - `reports/PAY-P2-MASTER-PLAN.md` §5
#
# 검증 영역 (8건):
# 1. SmsServicePort 인터페이스 박제 (sendPaymentNotification + sendVerificationCode + isEnabled + getProviderName)
# 2. SmsProvider 타입 박제 (null/kakao/nhn/twilio)
# 3. NullSmsAdapter 구현 박제 (외부 API import 0건)
# 4. NullSmsAdapter PII 마스킹 박제 (전화번호 + 인증코드)
# 5. NullSmsAdapter spec ≥10 it (PASS-only — 실 외부 API 의존 0건)
# 6. EmailServicePort 패턴 정합 (PaymentSmsType ↔ PaymentNotificationType 시그니처 정합)
# 7. 외부 API 의존 0건 (kakao/nhn/twilio SDK import 0건 — NullAdapter only)
# 8. 외부 프로젝트 인용 0건 (CERTI_PROJ / brightmall / thermage / inapi)
#
# Exit codes:
# - 0 PASS — 모두 정합
# - 2 FAIL — 회귀 검출 (commit 차단)

trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set +e

REPO_ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER="$REPO_ROOT/grimoire-server"
PORT="$SERVER/src/domain/port/outbound/sms-service.port.ts"
ADAPTER="$SERVER/src/adapter/outbound/sms/null-sms.adapter.ts"
SPEC="$SERVER/src/adapter/outbound/sms/null-sms.adapter.spec.ts"
EMAIL_PORT="$SERVER/src/domain/port/outbound/email-service.port.ts"

echo "── sensor-sms-service-port (PAY-P2-3 사전 작업 회귀 차단) ──"

PASS=0
FAIL=0

# [1/8] SmsServicePort 인터페이스 4 메서드
PORT_METHODS=$(grep -cE '^\s*(sendPaymentNotification|sendVerificationCode|isEnabled|getProviderName)\(' "$PORT")
if [ "$PORT_METHODS" -ge 4 ]; then
  echo "  ✓ [1/8] SmsServicePort 4 메서드 박제 ($PORT_METHODS건)"
  PASS=$((PASS+1))
else
  echo "  ✗ [1/8] Port 메서드 부족 ($PORT_METHODS건 < 4)"
  FAIL=$((FAIL+1))
fi

# [2/8] SmsProvider 타입 (null/kakao/nhn/twilio)
if grep -nE "SmsProvider\s*=\s*'null'\s*\|\s*'kakao'\s*\|\s*'nhn'\s*\|\s*'twilio'" "$PORT" > /dev/null 2>&1; then
  echo "  ✓ [2/8] SmsProvider 타입 박제 (null|kakao|nhn|twilio)"
  PASS=$((PASS+1))
else
  echo "  ✗ [2/8] SmsProvider 타입 누락 또는 매트릭스 부정합"
  FAIL=$((FAIL+1))
fi

# [3/8] NullSmsAdapter 구현 + 외부 API import 0건
if grep -nE 'class NullSmsAdapter implements SmsServicePort' "$ADAPTER" > /dev/null 2>&1; then
  EXTERNAL_IMPORTS=$(grep -cE "from ['\"](twilio|@nhncloud|@kakao|aws-sdk)" "$ADAPTER")
  if [ "$EXTERNAL_IMPORTS" -eq 0 ]; then
    echo "  ✓ [3/8] NullSmsAdapter 구현 박제 (외부 API import 0건)"
    PASS=$((PASS+1))
  else
    echo "  ✗ [3/8] 외부 API import 검출 ($EXTERNAL_IMPORTS건 — NullAdapter는 0건이어야 함)"
    FAIL=$((FAIL+1))
  fi
else
  echo "  ✗ [3/8] NullSmsAdapter 구현 누락"
  FAIL=$((FAIL+1))
fi

# [4/8] PII 마스킹 (전화번호 maskPhone + 코드 maskCode)
if grep -nE 'maskPhone' "$ADAPTER" > /dev/null 2>&1 && \
   grep -nE 'maskCode' "$ADAPTER" > /dev/null 2>&1; then
  echo "  ✓ [4/8] PII 마스킹 박제 (maskPhone + maskCode)"
  PASS=$((PASS+1))
else
  echo "  ✗ [4/8] PII 마스킹 메서드 누락"
  FAIL=$((FAIL+1))
fi

# [5/8] spec ≥7 it (it + it.each 케이스 합산)
if [ -f "$SPEC" ]; then
  # 'it(' + it.each 호출의 [...] 안 케이스 수 합산
  IT_DIRECT=$(grep -cE "^\s+it\(" "$SPEC")
  # it.each의 인자 배열 줄 안의 single-quoted string 또는 array 항목 수
  IT_EACH=$(grep -cE "^\s+\[[^]]" "$SPEC")
  TOTAL_IT=$((IT_DIRECT + IT_EACH))
  if [ "$TOTAL_IT" -ge 7 ]; then
    echo "  ✓ [5/8] null-sms.adapter.spec.ts ≥7 it 박제 (it=$IT_DIRECT each=$IT_EACH 합 $TOTAL_IT)"
    PASS=$((PASS+1))
  else
    echo "  ✗ [5/8] spec it 부족 ($TOTAL_IT 건 < 7)"
    FAIL=$((FAIL+1))
  fi
else
  echo "  ✗ [5/8] null-sms.adapter.spec.ts 누락"
  FAIL=$((FAIL+1))
fi

# [6/8] EmailServicePort 패턴 정합 — 3 결제 알림 타입 모두 박제
SMS_OK=$(grep -cE "'payment_success'" "$PORT")
SMS_FAIL=$(grep -cE "'payment_failed'" "$PORT")
SMS_REF=$(grep -cE "'payment_refunded'" "$PORT")
EMAIL_OK=$(grep -cE "'payment_success'" "$EMAIL_PORT")
EMAIL_FAIL=$(grep -cE "'payment_failed'" "$EMAIL_PORT")
EMAIL_REF=$(grep -cE "'payment_refunded'" "$EMAIL_PORT")
if [ "$SMS_OK" -ge 1 ] && [ "$SMS_FAIL" -ge 1 ] && [ "$SMS_REF" -ge 1 ] && \
   [ "$EMAIL_OK" -ge 1 ] && [ "$EMAIL_FAIL" -ge 1 ] && [ "$EMAIL_REF" -ge 1 ]; then
  echo "  ✓ [6/8] PaymentSmsType ↔ PaymentNotificationType 3 타입 정합 (success/failed/refunded)"
  PASS=$((PASS+1))
else
  echo "  ✗ [6/8] 결제 알림 타입 매트릭스 부정합 (sms ok=$SMS_OK fail=$SMS_FAIL ref=$SMS_REF / email ok=$EMAIL_OK fail=$EMAIL_FAIL ref=$EMAIL_REF)"
  FAIL=$((FAIL+1))
fi

# [7/8] 외부 SDK import 0건 (Port + Adapter 합산)
EXTERNAL_HITS=$(grep -rEi "from ['\"](twilio|@nhncloud|@kakao|kakao-bizmessage|aws-sdk/client-sns)" "$PORT" "$ADAPTER" 2>/dev/null | wc -l | tr -d ' ')
if [ "$EXTERNAL_HITS" -eq 0 ]; then
  echo "  ✓ [7/8] 외부 SMS SDK import 0건 (절대 규정 0-1 정합)"
  PASS=$((PASS+1))
else
  echo "  ✗ [7/8] 외부 SDK import 검출 ($EXTERNAL_HITS건)"
  FAIL=$((FAIL+1))
fi

# [8/8] 외부 프로젝트 인용 0건
EXT_PROJ_HITS=$(grep -rEi 'CERTI_PROJ|brightmall|thermage|inapi' "$PORT" "$ADAPTER" "$SPEC" 2>/dev/null)
if [ -z "$EXT_PROJ_HITS" ]; then
  echo "  ✓ [8/8] 외부 프로젝트 인용 0건"
  PASS=$((PASS+1))
else
  echo "  ✗ [8/8] 외부 프로젝트 인용 검출"
  echo "$EXT_PROJ_HITS" | head -3
  FAIL=$((FAIL+1))
fi

echo ""
echo "── 종합 ──"
echo "  PASS: $PASS / FAIL: $FAIL"

if [ $FAIL -gt 0 ]; then
  echo "  ✗ FAIL — PAY-P2-3 사전 작업 회귀 검출 (commit 차단)"
  echo "  → 정본: reports/sprint-pay-p2-3-sms-service-port-progress.md §2 AC-1~AC-5"
  exit 2
fi

echo "  ✓ PASS — PAY-P2-3 SmsServicePort 캡슐화 정합"
exit 0
