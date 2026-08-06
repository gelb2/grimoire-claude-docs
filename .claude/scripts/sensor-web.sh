#!/bin/bash
# sensor-web.sh — grimoire-web 빌드 건전성 센서
# 에이전트는 이 스크립트의 raw stdout을 reports/DEV_REPORT.md에 전체 첨부해야 함
set -u
START_TIME=$(date +%s)
cd /Users/sokol/Git/ProjectGrimoire/grimoire-web

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

# [3/3] 프로덕션 빌드 — Turbopack .next 캐시 stale 회복탄력성 (2026-04-30 #10)
# 첫 시도 실패 시 .next 정리 후 1회 재시도. 원인: next/font/google이 hash 기반 CSS 모듈을 생성(예: noto_serif_kr_fbd4d516.module.css), .next 캐시가 stale이면 module-not-found.
echo ""
echo "=== [3/3] 프로덕션 빌드 ==="
if npm run build; then
  echo "[RESULT] PASS"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "[WARN] 1차 빌드 실패 — .next 캐시 stale 가능성. 정리 후 재시도..."
  rm -rf .next
  if npm run build; then
    echo "[RESULT] PASS (.next 정리 후 재시도 성공)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "[RESULT] FAIL (재시도에도 실패)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_STEPS+=("[3/3] 프로덕션 빌드")
  fi
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=== 센서 요약 ==="
echo "PASS: $PASS_COUNT/3"
echo "FAIL: $FAIL_COUNT/3"
echo "실행 시간: ${DURATION}s"

if [ $FAIL_COUNT -eq 0 ]; then
  echo "=== 센서 전체 PASS ==="
  RESULT_TAG="PASS"; RC=0
else
  echo "=== 센서 FAIL — 실패한 단계: ${FAIL_STEPS[*]} ==="
  RESULT_TAG="FAIL"; RC=1
fi

# sensor-log 박제 (2026-05-02 H8)
bash "$(dirname "$0")/sensor-log.sh" "sensor-web" "$RESULT_TAG" "PASS=$PASS_COUNT FAIL=$FAIL_COUNT duration=${DURATION}s" 2>/dev/null || true
exit $RC
