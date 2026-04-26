#!/usr/bin/env bash
# sensor-cost-margin.sh — ai-cost-table.md 안전배수 ≥3.0× 자동 검증 (PLANNING §0 강제)
#
# 동기 (HARNESS §10 Phase 4 + §0 원가 철칙):
#   - cost-accountant가 ai-cost-table.md 단독 관리하지만, 코드 변경 없이는 자동 검증 부재
#   - AI 가격 변동(Anthropic/OpenAI 가격 인상) 시 안전배수 자동 재계산 필요
#   - 본 sensor가 ai-cost-table.md 안전배수 컬럼 파싱 → 모두 ≥3.0× 인지 자동 검증
#
# 검사 항목:
#   1. ai-cost-table.md 안전배수 컬럼 모두 ≥3.0×
#   2. 안전배수 ≥3.0× 미만 (FAIL) / 3.0~3.5× (WARN, 안전 마진 ↓)
#   3. 환율 가정 (USD ₩1,474) stale 검사 (30일 이상)
#   4. 가격 출처 갱신일 stale (30일 이상)
#   5. 마진율 50% 이상 유지 (사용자 수익 확보)
#
# 사용:
#   sensor-cost-margin.sh         # 전체 검사
#   sensor-cost-margin.sh --quiet # PASS 시 출력 없음
#   sensor-cost-margin.sh --strict # FAIL 시 exit 1

set -u

PROJECT_ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
COST_TABLE="$PROJECT_ROOT/grimoire-server/docs/ai-cost-table.md"
LOG_DIR="$PROJECT_ROOT/.claude/state"
OUTPUT_FILE="$LOG_DIR/cost-margin.jsonl"

mkdir -p "$LOG_DIR"

QUIET=0
STRICT=0
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --strict) STRICT=1 ;;
  esac
done

if [ ! -f "$COST_TABLE" ]; then
  [ "$QUIET" -eq 0 ] && echo "[sensor-cost-margin] ai-cost-table.md 없음: $COST_TABLE"
  exit 1
fi

[ "$QUIET" -eq 0 ] && echo "=== sensor-cost-margin ($(date +'%H:%M:%S')) ==="
[ "$QUIET" -eq 0 ] && echo "분석 대상: $COST_TABLE"
[ "$QUIET" -eq 0 ] && echo ""

export COST_TABLE QUIET

RESULT=$(python3 <<'PYEOF'
import os, re, sys
from datetime import datetime, timezone

COST_TABLE = os.environ['COST_TABLE']
NEW_DAYS_THRESHOLD = 30

with open(COST_TABLE, encoding='utf-8') as f:
    content = f.read()

# 1. 안전배수 컬럼 추출 (마크다운 표 파싱)
# 형식: | ... | **3.49×** | 71.4% | ✅ PASS |
# 또는: | ... | **3.49×** | ✅ PASS |
# 안전배수는 "**N.NN×**" 또는 "N.NN×" 형태
margin_pattern = re.compile(r'\|\s*\*?\*?(\d+\.\d+)×\*?\*?\s*\|')
margins = margin_pattern.findall(content)

# 판정 컬럼 추출 (✅ PASS / ❌ FAIL)
verdict_pattern = re.compile(r'\|\s*(✅\s*PASS|❌\s*FAIL|⚠️?\s*WARN|🚨\s*CRITICAL)\s*\|')
verdicts = verdict_pattern.findall(content)

# 2. 환율 가정 + 가격 출처 갱신일
# 형식: | 환율 | 1 USD = ₩1,474 | tradingeconomics | 2026-04-16 |
date_pattern = re.compile(r'\|\s*\d{4}-\d{2}-\d{2}\s*\|')
dates_in_table = date_pattern.findall(content)

# 최종 갱신일 추출
last_update_match = re.search(r'최종 갱신:\s*(\d{4}-\d{2}-\d{2})', content)
last_update = last_update_match.group(1) if last_update_match else None

# 마진율 추출 (예: 71.4% / 73.7%)
margin_pct_pattern = re.compile(r'\|\s*(\d+\.\d+)%\s*\|')
margin_pcts = margin_pct_pattern.findall(content)

# 3. 검증
print("MARGIN_COUNT|" + str(len(margins)))

# 모든 안전배수 ≥3.0
fail_count = 0
warn_count = 0
all_margins = []
for m_str in margins:
    try:
        m = float(m_str)
        all_margins.append(m)
        if m < 3.0:
            fail_count += 1
            print("FAIL_MARGIN|" + m_str)
        elif m < 3.5:
            warn_count += 1
            print("WARN_MARGIN|" + m_str)
    except ValueError:
        pass

print("FAIL_COUNT|" + str(fail_count))
print("WARN_COUNT|" + str(warn_count))
if all_margins:
    print("MIN_MARGIN|" + ("%.2f" % min(all_margins)))
    print("MAX_MARGIN|" + ("%.2f" % max(all_margins)))
    print("AVG_MARGIN|" + ("%.2f" % (sum(all_margins) / len(all_margins))))

# 판정 컬럼 카운트
pass_verdicts = sum(1 for v in verdicts if 'PASS' in v)
fail_verdicts = sum(1 for v in verdicts if 'FAIL' in v or 'CRITICAL' in v)
print("VERDICT_PASS|" + str(pass_verdicts))
print("VERDICT_FAIL|" + str(fail_verdicts))

# 마진율 50% 이상 검사
low_pct_count = 0
for p_str in margin_pcts:
    try:
        p = float(p_str)
        if p < 50.0:
            low_pct_count += 1
    except ValueError:
        pass
print("LOW_MARGIN_PCT_COUNT|" + str(low_pct_count))

# 4. 갱신일 stale 검사
if last_update:
    try:
        last_dt = datetime.strptime(last_update, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        now = datetime.now(timezone.utc)
        days_since = (now - last_dt).days
        print("LAST_UPDATE|" + last_update)
        print("DAYS_SINCE_UPDATE|" + str(days_since))
        if days_since > NEW_DAYS_THRESHOLD:
            print("STALE|true")
        else:
            print("STALE|false")
    except ValueError:
        print("STALE|unknown")
else:
    print("STALE|no_date_found")
PYEOF
)

# 결과 파싱
MARGIN_COUNT=$(echo "$RESULT" | grep "^MARGIN_COUNT|" | cut -d'|' -f2)
FAIL_COUNT=$(echo "$RESULT" | grep "^FAIL_COUNT|" | cut -d'|' -f2)
WARN_COUNT=$(echo "$RESULT" | grep "^WARN_COUNT|" | cut -d'|' -f2)
MIN_MARGIN=$(echo "$RESULT" | grep "^MIN_MARGIN|" | cut -d'|' -f2)
MAX_MARGIN=$(echo "$RESULT" | grep "^MAX_MARGIN|" | cut -d'|' -f2)
AVG_MARGIN=$(echo "$RESULT" | grep "^AVG_MARGIN|" | cut -d'|' -f2)
VERDICT_PASS=$(echo "$RESULT" | grep "^VERDICT_PASS|" | cut -d'|' -f2)
VERDICT_FAIL=$(echo "$RESULT" | grep "^VERDICT_FAIL|" | cut -d'|' -f2)
LOW_PCT=$(echo "$RESULT" | grep "^LOW_MARGIN_PCT_COUNT|" | cut -d'|' -f2)
LAST_UPDATE=$(echo "$RESULT" | grep "^LAST_UPDATE|" | cut -d'|' -f2)
DAYS_SINCE=$(echo "$RESULT" | grep "^DAYS_SINCE_UPDATE|" | cut -d'|' -f2)
STALE=$(echo "$RESULT" | grep "^STALE|" | cut -d'|' -f2)

if [ "$QUIET" -eq 0 ]; then
  echo "안전배수 항목 수: $MARGIN_COUNT"
  echo "  최소: ${MIN_MARGIN:-N/A}× / 평균: ${AVG_MARGIN:-N/A}× / 최대: ${MAX_MARGIN:-N/A}×"
  echo "  3.0× 미만 (FAIL): $FAIL_COUNT 건"
  echo "  3.0~3.5× (WARN): $WARN_COUNT 건"
  echo ""
  echo "판정 컬럼: PASS $VERDICT_PASS / FAIL $VERDICT_FAIL"
  echo "마진율 50% 미만: $LOW_PCT 건"
  echo ""
  echo "최종 갱신: ${LAST_UPDATE:-알 수 없음} (${DAYS_SINCE:-?}일 전, stale=$STALE)"

  # FAIL 항목 출력
  if [ "$FAIL_COUNT" -gt 0 ]; then
    echo ""
    echo "🚨 FAIL 안전배수 (즉시 검토):"
    echo "$RESULT" | grep "^FAIL_MARGIN|" | while IFS='|' read -r _ m; do
      echo "  - $m× < 3.0×"
    done
  fi
  if [ "$WARN_COUNT" -gt 0 ]; then
    echo ""
    echo "⚠️ WARN 안전배수 (모니터링):"
    echo "$RESULT" | grep "^WARN_MARGIN|" | while IFS='|' read -r _ m; do
      echo "  - $m× (3.0~3.5×)"
    done
  fi
  echo ""
fi

# 종합 판정
TOTAL_FAIL=$FAIL_COUNT
TOTAL_WARN=$WARN_COUNT
[ "$VERDICT_FAIL" -gt 0 ] && TOTAL_FAIL=$((TOTAL_FAIL + VERDICT_FAIL))
[ "$LOW_PCT" -gt 0 ] && TOTAL_WARN=$((TOTAL_WARN + LOW_PCT))
[ "$STALE" = "true" ] && TOTAL_WARN=$((TOTAL_WARN + 1))

RESULT_STATUS="PASS"
EXIT_CODE=0
if [ "$TOTAL_FAIL" -gt 0 ]; then
  RESULT_STATUS="FAIL"
  EXIT_CODE=$([ "$STRICT" -eq 1 ] && echo 1 || echo 0)
  [ "$QUIET" -eq 0 ] && echo "[RESULT] FAIL — 안전배수 또는 판정 위반 ($TOTAL_FAIL 건). cost-accountant 즉시 호출 권장"
elif [ "$TOTAL_WARN" -gt 0 ]; then
  RESULT_STATUS="WARN"
  [ "$QUIET" -eq 0 ] && echo "[RESULT] WARN — $TOTAL_WARN 건 검토 (안전 마진 ↓ 또는 stale)"
  EXIT_CODE=2
else
  [ "$QUIET" -eq 0 ] && echo "[RESULT] PASS — 모든 안전배수 ≥3.5× + 최신 갱신"
fi

# JSONL 적재
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"ts":"%s","margin_count":%s,"min":%s,"avg":%s,"max":%s,"fail":%s,"warn":%s,"verdict_pass":%s,"verdict_fail":%s,"low_pct":%s,"days_since":%s,"stale":"%s","status":"%s"}\n' \
  "$TS" "${MARGIN_COUNT:-0}" "${MIN_MARGIN:-0}" "${AVG_MARGIN:-0}" "${MAX_MARGIN:-0}" \
  "${FAIL_COUNT:-0}" "${WARN_COUNT:-0}" "${VERDICT_PASS:-0}" "${VERDICT_FAIL:-0}" \
  "${LOW_PCT:-0}" "${DAYS_SINCE:-0}" "${STALE:-unknown}" "$RESULT_STATUS" \
  >> "$OUTPUT_FILE"

# sensor-log 적재
SENSOR_LOG="/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-log.sh"
if [ -x "$SENSOR_LOG" ]; then
  bash "$SENSOR_LOG" "sensor-cost-margin" "$EXIT_CODE" "FAIL=$TOTAL_FAIL WARN=$TOTAL_WARN min=$MIN_MARGIN×" 2>/dev/null || true
fi

exit $EXIT_CODE
