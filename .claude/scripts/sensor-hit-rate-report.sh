#!/usr/bin/env bash
# sensor-hit-rate-report.sh — sensor-hits.jsonl 집계 → 주간 hit-rate 리포트
#
# 출력:
#   - sensor별 (총 호출 / PASS / WARN / FAIL) + hit-rate (FAIL/총)
#   - 7일 prune된 데이터 기준
#   - silent sensor 식별 (호출 없는 sensor)
#
# Fowler "Silent sensors" 실패모드 직접 대응 (HARNESS §4)

set -u

LOG_FILE="/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/state/sensor-hits.jsonl"

if [ ! -f "$LOG_FILE" ]; then
  echo "[sensor-hit-rate] sensor-hits.jsonl 없음. sensor-log.sh로 적재 필요."
  exit 0
fi

TOTAL=$(wc -l < "$LOG_FILE" | tr -d ' ')
echo "=== Sensor Hit-Rate Report ==="
echo "데이터 범위: 최근 7일 (sensor-log.sh prune)"
echo "총 이벤트: $TOTAL"
echo ""

if [ "$TOTAL" -eq 0 ]; then
  echo "이벤트 0건. sensor 호출 부재 — 모든 sensor가 silent 상태."
  exit 0
fi

# sensor별 카운트
echo "─── sensor별 호출·결과 ───"
printf "%-30s %6s %6s %6s %6s %10s\n" "sensor" "TOTAL" "PASS" "WARN" "FAIL" "FAIL_RATE"

# unique sensor 추출
SENSORS=$(awk -F'"sensor":"' 'NF>1{n=split($2,a,"\""); if(n>0) print a[1]}' "$LOG_FILE" | sort -u)

for s in $SENSORS; do
  # grep -c는 매칭 0건이면 stdout "0" + exit 1. set -u 환경에서 stderr 무시
  TOT=$(grep -c "\"sensor\":\"$s\"" "$LOG_FILE" 2>/dev/null) || TOT=0
  P=$(grep -c "\"sensor\":\"$s\".*\"result\":\"PASS\"" "$LOG_FILE" 2>/dev/null) || P=0
  W=$(grep -c "\"sensor\":\"$s\".*\"result\":\"WARN\"" "$LOG_FILE" 2>/dev/null) || W=0
  F=$(grep -c "\"sensor\":\"$s\".*\"result\":\"FAIL\"" "$LOG_FILE" 2>/dev/null) || F=0
  if [ "$TOT" -gt 0 ]; then
    RATE=$(awk -v f="$F" -v t="$TOT" 'BEGIN{printf "%.1f%%", (f/t)*100}')
  else
    RATE="N/A"
  fi
  printf "%-30s %6d %6d %6d %6d %10s\n" "$s" "$TOT" "$P" "$W" "$F" "$RATE"
done

echo ""
echo "─── PASS-only sensor 식별 (FAIL/WARN 0건 — 검사 항목 미달성 가능성) ───"
for s in $SENSORS; do
  W=$(grep -c "\"sensor\":\"$s\".*\"result\":\"WARN\"" "$LOG_FILE" 2>/dev/null) || W=0
  F=$(grep -c "\"sensor\":\"$s\".*\"result\":\"FAIL\"" "$LOG_FILE" 2>/dev/null) || F=0
  if [ "$W" -eq 0 ] && [ "$F" -eq 0 ]; then
    echo "  💡 PASS-only: $s (정밀화 가치 검토 — 임계값이 너무 느슨할 가능성)"
  fi
done

echo ""
echo "─── silent sensor 식별 (마지막 호출 시간 + 30일 stale) ───"
echo "(.claude/scripts/sensor-*.sh 중 호출 없거나 stale)"
ALL_SENSORS=$(ls /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-*.sh 2>/dev/null | xargs -I{} basename {} .sh | sort -u)
NOW_EPOCH=$(date "+%s")
for s in $ALL_SENSORS; do
  # sensor-log, sensor-hit-rate-report는 메타라 제외
  case "$s" in
    sensor-log|sensor-hit-rate-report) continue ;;
  esac
  # sensor 호출 마지막 ts 추출 (없으면 빈 문자열)
  LAST_TS=$(grep "\"sensor\":\"$s\"" "$LOG_FILE" 2>/dev/null | tail -1 | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')
  if [ -z "$LAST_TS" ]; then
    echo "  🚫 never: $s (sensor-hits.jsonl 박제 0건 — sensor-log.sh 미연동 또는 7일 prune된 후 미실행)"
    continue
  fi
  LAST_EPOCH=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_TS" "+%s" 2>/dev/null || echo "0")
  STALE_DAYS=$(( (NOW_EPOCH - LAST_EPOCH) / 86400 ))
  if [ "$STALE_DAYS" -gt 30 ]; then
    echo "  ⚠️ stale ${STALE_DAYS}일: $s (last=$LAST_TS — 30일 임계 초과)"
  elif [ "$STALE_DAYS" -gt 7 ]; then
    echo "  ⏱  silent ${STALE_DAYS}일: $s (last=$LAST_TS — 7일 임계 초과)"
  fi
done

echo ""
echo "=== 끝 ==="
