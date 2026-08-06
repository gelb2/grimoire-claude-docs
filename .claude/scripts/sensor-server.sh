#!/bin/bash
# sensor-server.sh — grimoire-server 빌드 건전성 센서
# 에이전트는 이 스크립트의 raw stdout을 reports/DEV_REPORT.md에 전체 첨부해야 함
# vibe-coding 게이트 체크 패턴 + GMP v2.2 독립 검증 원칙 구현
# sensor-log 자동 박제 (트랙 1-C 보강 — cd 후에도 절대경로 보존)
_SENSOR_LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SENSOR_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
trap '_rc=$?; bash "$_SENSOR_LOG_DIR/sensor-log.sh" "$_SENSOR_NAME" "$_rc" "" 2>/dev/null || true' EXIT

set -u  # set -e 빼고 각 단계 수동 처리 (실패 시에도 나머지 돌려서 전체 상태 파악)
START_TIME=$(date +%s)
cd /Users/sokol/Git/ProjectGrimoire/grimoire-server

PASS_COUNT=0
FAIL_COUNT=0
FAIL_STEPS=()

run_step() {
  local step_name="$1"
  shift
  echo ""
  echo "=== $step_name ==="
  if "$@"; then
    echo "[RESULT] PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "[RESULT] FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_STEPS+=("$step_name")
  fi
}

echo "=== sensor-server.sh 시작 $(date '+%Y-%m-%d %H:%M:%S') ==="
echo "작업 디렉토리: $(pwd)"
echo "Node: $(node --version), npm: $(npm --version)"

run_step "[1/4] TypeScript 컴파일" npx tsc --noEmit

# [2/4] Jest 테스트 — flaky 회복탄력성 (2026-05-02 #10_6 추가)
# 사유: jest multi-worker가 sensor-web 동시 실행 시 자원 경합으로 일회성 FAIL 가능 (#10_6 검증 발견)
# 패턴: sensor-web .next stale fallback 정합 (Fowler Resilience)
echo ""
echo "=== [2/4] Jest 테스트 ==="
if npm test; then
  echo "[RESULT] PASS"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "[WARN] 1차 Jest 실패 — 일회성 flaky 가능성 (worker 경합/timeout). 5초 대기 후 재시도..."
  sleep 5
  if npm test -- --runInBand; then
    echo "[RESULT] PASS (--runInBand single-worker 재시도 성공)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "[RESULT] FAIL (재시도에도 실패 — 진짜 회귀)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_STEPS+=("[2/4] Jest 테스트")
  fi
fi

run_step "[3/4] 프로덕션 빌드" npm run build
run_step "[4/4] Prisma 스키마 검증" npx prisma validate

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=== 센서 요약 ==="
echo "PASS: $PASS_COUNT/4"
echo "FAIL: $FAIL_COUNT/4"
echo "실행 시간: ${DURATION}s"

if [ $FAIL_COUNT -eq 0 ]; then
  echo "=== 센서 전체 PASS ==="
  exit 0
else
  echo "=== 센서 FAIL — 실패한 단계: ${FAIL_STEPS[*]} ==="
  exit 1
fi
