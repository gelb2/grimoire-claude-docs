#!/usr/bin/env bash
# sensor-log.sh — sensor 실행 결과를 jsonl로 적재 (hit-rate 측정 인프라)
#
# 사용 (2가지 모드):
#   bash sensor-log.sh <sensor-name> <exit-code> [<extra>]    # exit code 모드 (0=PASS / 1=FAIL / 2=WARN)
#   bash sensor-log.sh <sensor-name> <PASS|WARN|FAIL> [<extra>]  # 명시 result 모드 (2026-05-02 H8 추가)
#
# 사유 (H8): 일부 sensor는 exit code 컨벤션이 다름 (1=WARN, 2=FAIL — agent-priority-labels / eval-trend 등).
# 명시 result 모드를 사용하면 exit code 매핑 충돌을 회피. 기존 호출자 (sensor-cost-margin / sensor-deploy-drift)는 호환.
#
# 예:
#   bash sensor-log.sh sensor-secret-leak 0 "FAIL=0 WARN=0"      # exit 0 → PASS
#   bash sensor-log.sh sensor-eval-trend WARN "회귀 30%"          # 명시 WARN
#
# 적재 위치:
#   .claude/state/sensor-hits.jsonl (한 줄 1 이벤트)
#
# 집계는 별도 (sensor-hit-rate-report.sh 또는 jq 조합)

set -u

NAME="${1:-unknown}"
EXIT_CODE="${2:-?}"
EXTRA="${3:-}"

LOG_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/state"
LOG_FILE="$LOG_DIR/sensor-hits.jsonl"

mkdir -p "$LOG_DIR"

# 7일 TTL prune (LRU): 7일 이전 라인만 보존된 새 파일로 교체
if [ -f "$LOG_FILE" ]; then
  CUTOFF=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "7 days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
  if [ -n "$CUTOFF" ]; then
    TMP="$LOG_FILE.tmp.$$"
    awk -v c="$CUTOFF" '
      match($0, /"ts":"([^"]+)"/, m) {
        if (m[1] >= c) print
      }
    ' "$LOG_FILE" > "$TMP" 2>/dev/null && mv "$TMP" "$LOG_FILE"
  fi
fi

# 새 이벤트 append
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
case "$EXIT_CODE" in
  PASS|WARN|FAIL|UNKNOWN)  # 명시 result 모드 (H8)
    RESULT="$EXIT_CODE"
    EXIT_CODE_NUM="null"  # JSON null (exit code 미상)
    ;;
  0) RESULT="PASS"; EXIT_CODE_NUM="$EXIT_CODE" ;;
  1) RESULT="FAIL"; EXIT_CODE_NUM="$EXIT_CODE" ;;
  2) RESULT="WARN"; EXIT_CODE_NUM="$EXIT_CODE" ;;
  *)
    # 숫자가 아니면 null + UNKNOWN
    if [ "$EXIT_CODE" = "?" ] || ! [ "$EXIT_CODE" -eq "$EXIT_CODE" ] 2>/dev/null; then
      RESULT="UNKNOWN"; EXIT_CODE_NUM="null"
    else
      RESULT="UNKNOWN"; EXIT_CODE_NUM="$EXIT_CODE"
    fi
    ;;
esac
EXIT_CODE="$EXIT_CODE_NUM"

# extra의 큰따옴표는 백슬래시 이스케이프
EXTRA_ESCAPED=$(printf '%s' "$EXTRA" | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '{"ts":"%s","sensor":"%s","exit":%s,"result":"%s","extra":"%s"}\n' \
  "$TS" "$NAME" "$EXIT_CODE" "$RESULT" "$EXTRA_ESCAPED" >> "$LOG_FILE"

exit 0
