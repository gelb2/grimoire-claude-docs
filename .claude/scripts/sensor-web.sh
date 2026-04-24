#!/bin/bash
# sensor-web.sh — grimoire-web 빌드 건전성 센서
# 에이전트는 이 스크립트의 raw stdout을 reports/DEV_REPORT.md에 전체 첨부해야 함
set -u
START_TIME=$(date +%s)
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web

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

echo "=== sensor-web.sh 시작 $(date '+%Y-%m-%d %H:%M:%S') ==="
echo "작업 디렉토리: $(pwd)"
echo "Node: $(node --version), npm: $(npm --version)"

run_step "[1/3] TypeScript 컴파일" npx tsc --noEmit
run_step "[2/3] Vitest 테스트" npm test
run_step "[3/3] 프로덕션 빌드" npm run build

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=== 센서 요약 ==="
echo "PASS: $PASS_COUNT/3"
echo "FAIL: $FAIL_COUNT/3"
echo "실행 시간: ${DURATION}s"

if [ $FAIL_COUNT -eq 0 ]; then
  echo "=== 센서 전체 PASS ==="
  exit 0
else
  echo "=== 센서 FAIL — 실패한 단계: ${FAIL_STEPS[*]} ==="
  exit 1
fi
