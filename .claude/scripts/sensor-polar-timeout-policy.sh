#!/bin/bash
# sensor-polar-timeout-policy.sh
# PAY-P3-B 회귀 차단 — Polar SDK timeout 옵션 + classifyPolarError + 분기 처리 grep
#
# 정본: .claude/shared-contracts.md §24 PolarSDKTimeoutPolicy
#
# 검증 영역 (5건):
#   1. polar.adapter.ts — Polar SDK timeout 옵션 명시 (timeoutMs 또는 POLAR_SDK_TIMEOUT_MS 또는 AbortSignal)
#   2. polar.adapter.ts — classifyPolarError helper 박제 + 5분류 모두 박제
#   3. payment.usecase.ts — classifyPolarError 분기 처리 (client_4xx + webhook_permanent_failed)
#   4. payment-gateway.port.ts — PolarErrorClass + classifyPolarError? Optional 메서드 박제
#   5. shared-contracts.md §24 PolarSDKTimeoutPolicy 박제
#
# Exit codes:
#   0 = PASS / 1 = FAIL

# sensor-log 자동 박제 (트랙 1-A 정합)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
SERVER="$ROOT/grimoire-server"
POLAR_ADAPTER="$SERVER/src/adapter/outbound/payment/polar.adapter.ts"
PAYMENT_USECASE="$SERVER/src/application/payment/payment.usecase.ts"
GATEWAY_PORT="$SERVER/src/domain/port/outbound/payment-gateway.port.ts"
SHARED_CONTRACTS="$ROOT/.claude/shared-contracts.md"

PASS=0
FAIL=0

echo "=== sensor-polar-timeout-policy ($(date '+%H:%M:%S')) ==="
echo ""

# 1. Polar SDK timeout 옵션 박제 (timeoutMs 또는 POLAR_SDK_TIMEOUT_MS 또는 AbortSignal)
if grep -qE "(timeoutMs|POLAR_SDK_TIMEOUT_MS|AbortSignal\.timeout)" "$POLAR_ADAPTER" 2>/dev/null; then
  echo "  [PASS] polar.adapter: SDK timeout 옵션 박제 (timeoutMs / POLAR_SDK_TIMEOUT_MS / AbortSignal)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] polar.adapter: timeout 옵션 박제 0건 — 워커 자원 leak 회귀"
  FAIL=$((FAIL + 1))
fi

# 2. classifyPolarError helper 박제 (5분류 모두 검증)
if grep -qE "classifyPolarError" "$POLAR_ADAPTER" 2>/dev/null; then
  ALL_CLASSES_OK=1
  for class in timeout network server_5xx client_4xx unknown; do
    if ! grep -qE "['\"]${class}['\"]" "$POLAR_ADAPTER" 2>/dev/null; then
      echo "  [FAIL] polar.adapter: classifyPolarError '${class}' 분류 박제 0건"
      ALL_CLASSES_OK=0
      FAIL=$((FAIL + 1))
    fi
  done
  if [ "$ALL_CLASSES_OK" = "1" ]; then
    echo "  [PASS] polar.adapter: classifyPolarError + 5분류 (timeout/network/server_5xx/client_4xx/unknown) 모두 박제"
    PASS=$((PASS + 1))
  fi
else
  echo "  [FAIL] polar.adapter: classifyPolarError helper 박제 0건"
  FAIL=$((FAIL + 1))
fi

# 3. payment.usecase.ts에 client_4xx → permanent_failed 분기 박제
if grep -qE "client_4xx" "$PAYMENT_USECASE" 2>/dev/null && \
   grep -qE "webhook_permanent_failed" "$PAYMENT_USECASE" 2>/dev/null; then
  echo "  [PASS] payment.usecase: client_4xx → webhook_permanent_failed 분기 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] payment.usecase: client_4xx → permanent_failed 분기 박제 0건"
  FAIL=$((FAIL + 1))
fi

# 4. payment-gateway.port.ts에 PolarErrorClass + classifyPolarError? Optional 박제
if grep -qE "PolarErrorClass" "$GATEWAY_PORT" 2>/dev/null && \
   grep -qE "classifyPolarError" "$GATEWAY_PORT" 2>/dev/null; then
  echo "  [PASS] payment-gateway.port: PolarErrorClass + classifyPolarError? Optional 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] payment-gateway.port: PolarErrorClass / classifyPolarError? Optional 박제 0건"
  FAIL=$((FAIL + 1))
fi

# 5. shared-contracts §24 박제
if grep -qE '## 24\. PolarSDKTimeoutPolicy' "$SHARED_CONTRACTS" 2>/dev/null; then
  echo "  [PASS] shared-contracts §24 PolarSDKTimeoutPolicy 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] shared-contracts §24 PolarSDKTimeoutPolicy 누락 — 인터페이스 정본 부재"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 누락 (PAY-P3-B Polar SDK timeout 정책 회귀)"
  exit 1
fi

echo "[RESULT] PASS — Polar SDK timeout 정책 (옵션 A + 5분류 + 분기 처리 + Optional Port + §24) 모두 박제"
exit 0
