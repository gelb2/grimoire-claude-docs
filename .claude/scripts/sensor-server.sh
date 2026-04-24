#!/bin/bash
# sensor-server.sh — grimoire-server 빌드 건전성 센서
# 에이전트는 이 스크립트의 raw stdout을 reports/DEV_REPORT.md에 전체 첨부해야 함
# vibe-coding 게이트 체크 패턴 + GMP v2.2 독립 검증 원칙 구현
set -u  # set -e 빼고 각 단계 수동 처리 (실패 시에도 나머지 돌려서 전체 상태 파악)
START_TIME=$(date +%s)
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server

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
run_step "[2/4] Jest 테스트" npm test
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
