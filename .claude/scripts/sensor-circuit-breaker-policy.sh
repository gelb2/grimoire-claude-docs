#!/bin/bash
# sensor-circuit-breaker-policy.sh — PAY-P3-H Circuit Breaker 정책 회귀 차단
#
# PAY-P3-H 박제 종료 후 회귀 차단 sensor.
# 10 검증: port + model + adapter + 적용 + AuditLog 4 action + shared-contracts + ADR + DB schema 0건.
#
# 정본:
# - `.claude/shared-contracts.md §27 CircuitBreakerPolicy`
# - `grimoire-server/ADR.md ADR-009`
# - `.claude/state/sprint-pay-p3-h-circuit-breaker-draft.md`

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SERVER="${ROOT}/grimoire-server"
fail_count=0

echo "[sensor-circuit-breaker-policy] PAY-P3-H 회귀 차단 검증 진입"

# 1. circuit-breaker.port.ts 박제
PORT_FILE="${SERVER}/src/domain/port/outbound/circuit-breaker.port.ts"
if [ ! -f "${PORT_FILE}" ]; then
  echo "FAIL [1/10]: circuit-breaker.port.ts 박제 0건 (${PORT_FILE})"
  fail_count=$((fail_count + 1))
else
  if ! grep -q "interface CircuitBreakerPort" "${PORT_FILE}"; then
    echo "FAIL [1/10]: CircuitBreakerPort 인터페이스 박제 0건"
    fail_count=$((fail_count + 1))
  fi
fi

# 2. 3 상태 enum 박제 (CLOSED / OPEN / HALF_OPEN)
MODEL_FILE="${SERVER}/src/domain/model/circuit-breaker-state.ts"
if [ ! -f "${MODEL_FILE}" ]; then
  echo "FAIL [2/10]: circuit-breaker-state.ts 박제 0건"
  fail_count=$((fail_count + 1))
else
  for state in CLOSED OPEN HALF_OPEN; do
    if ! grep -q "${state}" "${MODEL_FILE}"; then
      echo "FAIL [2/10]: circuit-breaker-state.ts '${state}' 박제 0건"
      fail_count=$((fail_count + 1))
    fi
  done
fi

# 3. InMemoryCircuitBreaker adapter 박제
ADAPTER_FILE="${SERVER}/src/adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.ts"
if [ ! -f "${ADAPTER_FILE}" ]; then
  echo "FAIL [3/10]: in-memory-circuit-breaker.adapter.ts 박제 0건"
  fail_count=$((fail_count + 1))
else
  if ! grep -q "implements CircuitBreakerPort" "${ADAPTER_FILE}"; then
    echo "FAIL [3/10]: InMemoryCircuitBreakerAdapter가 CircuitBreakerPort 구현 0건"
    fail_count=$((fail_count + 1))
  fi
fi

# 4. polar.adapter.ts circuit breaker DI 박제
POLAR_ADAPTER="${SERVER}/src/adapter/outbound/payment/polar.adapter.ts"
if ! grep -qE "circuitBreaker.*CircuitBreakerPort" "${POLAR_ADAPTER}"; then
  echo "FAIL [4/10]: polar.adapter CircuitBreaker DI 박제 0건"
  fail_count=$((fail_count + 1))
fi

# 5. polar.adapter.ts execute 래핑 박제 (2 호출점: create + list)
create_count=$(grep -cE "circuitBreaker\.execute\(.polar:checkouts:create" "${POLAR_ADAPTER}" || echo 0)
list_count=$(grep -cE "circuitBreaker\.execute\(.polar:checkouts:list" "${POLAR_ADAPTER}" || echo 0)
if [ "${create_count}" -lt 1 ] || [ "${list_count}" -lt 1 ]; then
  echo "FAIL [5/10]: polar.adapter circuitBreaker.execute 2 호출점 래핑 (create=${create_count}, list=${list_count})"
  fail_count=$((fail_count + 1))
fi

# 6. payment.usecase.ts CircuitOpenError 분기 박제
USECASE_FILE="${SERVER}/src/application/payment/payment.usecase.ts"
if ! grep -qE "CircuitOpenError" "${USECASE_FILE}"; then
  echo "FAIL [6/10]: payment.usecase CircuitOpenError 분기 박제 0건"
  fail_count=$((fail_count + 1))
fi
if ! grep -qE "ServiceUnavailableException" "${USECASE_FILE}"; then
  echo "FAIL [6/10]: payment.usecase ServiceUnavailableException 변환 박제 0건"
  fail_count=$((fail_count + 1))
fi

# 7. AuditLog circuit_breaker 4 action 박제 (adapter 영역)
for action in "circuit_breaker.open" "circuit_breaker.close" "circuit_breaker.half_open_trial" "circuit_breaker.reject"; do
  if ! grep -q "'${action}'" "${ADAPTER_FILE}"; then
    echo "FAIL [7/10]: in-memory-circuit-breaker.adapter '${action}' 박제 0건"
    fail_count=$((fail_count + 1))
  fi
done

# 8. spec ≥ 12 it 박제 (Draft §9-2 정합)
SPEC_FILE="${SERVER}/src/adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.spec.ts"
if [ ! -f "${SPEC_FILE}" ]; then
  echo "FAIL [8/10]: in-memory-circuit-breaker.adapter.spec.ts 박제 0건"
  fail_count=$((fail_count + 1))
else
  spec_count=$(grep -cE "^[[:space:]]+it\(" "${SPEC_FILE}" 2>/dev/null || echo 0)
  if [ "${spec_count}" -lt 12 ]; then
    echo "FAIL [8/10]: in-memory-circuit-breaker.adapter.spec.ts it 수 부족 (${spec_count} < 12)"
    fail_count=$((fail_count + 1))
  fi
fi

# 9. shared-contracts §27 박제
SHARED_CONTRACTS="${ROOT}/.claude/shared-contracts.md"
if ! grep -q "^## 27\. CircuitBreakerPolicy" "${SHARED_CONTRACTS}"; then
  echo "FAIL [9/10]: shared-contracts §27 CircuitBreakerPolicy 박제 0건"
  fail_count=$((fail_count + 1))
fi

# 10. ADR-009 박제 + DB schema 변경 0건 강제 (사용자 5/10 정합)
ADR_FILE="${SERVER}/ADR.md"
if ! grep -q "^## ADR-009" "${ADR_FILE}"; then
  echo "FAIL [10/10]: ADR-009 박제 0건"
  fail_count=$((fail_count + 1))
fi
# DB schema에 circuit breaker 모델 추가 0건 강제
if grep -qE "^model.*CircuitBreaker" "${SERVER}/prisma/schema.prisma" 2>/dev/null; then
  echo "FAIL [10/10]: schema.prisma circuit breaker 모델 추가 0건 강제 (사용자 5/10 정합 위반)"
  fail_count=$((fail_count + 1))
fi

if [ "${fail_count}" -eq 0 ]; then
  echo "PASS: PAY-P3-H Circuit Breaker 정책 정합 (10/10 검증)"
  exit 0
else
  echo "FAIL: ${fail_count}건 위반 — PAY-P3-H 회귀 차단"
  exit 1
fi
