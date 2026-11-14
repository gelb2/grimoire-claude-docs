#!/bin/bash
# sensor-eval-trend.sh — eval baseline.csv + edd-baseline.csv 30일 추세 분석
#
# 책 Ch 15 EDD 운영 — 단순 마지막 통과율만이 아니라 추세(slope/dispersion)로 회귀 조기 감지.
#
# 분석 항목 (regression + EDD 각각):
#   - 최근 30일 평균 통과율
#   - 7일 이동 평균 vs 30일 평균 (slope 양/음)
#   - 최근 10회 중 FAIL 횟수
#   - stale 검사 (마지막 실행이 7일 이상 전이면 WARN)
#
# 임계값:
#   - 30일 평균 ≥ 0.95 + 7일 mean ≥ 30일 mean → PASS
#   - 30일 평균 0.85~0.95 또는 7일 mean < 30일 mean (회귀 추세) → WARN
#   - 30일 평균 < 0.85 또는 stale > 7일 → FAIL
#
# Exit 0 PASS / 1 WARN / 2 FAIL

set +u

ROOT="/Users/sokol/Git/ProjectGrimoire"

echo "=== sensor-eval-trend (eval 30일 추세) ==="
echo ""

analyze() {
  local label="$1"
  local file="$2"
  local rate_field="$3"   # baseline.csv: 5 / edd: 8
  local total_field="$4"  # baseline.csv: 2 / edd: 5
  local min_total="$5"    # 단일 task / 초기 노이즈 제외 (regression: 10 / edd: 5)

  if [ ! -f "$file" ]; then
    echo "  ❌ FAIL $label: $file 없음"
    return 2
  fi

  # 마지막 전체 실행(total ≥ min_total) ts 추출 → stale 검사
  local last_ts=$(awk -F',' -v t="$total_field" -v m="$min_total" '
    NR > 1 && $t+0 >= m+0 { last=$1 } END { print last }
  ' "$file")
  local last_epoch=0
  if [ -n "$last_ts" ]; then
    last_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last_ts" "+%s" 2>/dev/null || echo "0")
  fi
  local now_epoch=$(date "+%s")
  local stale_days=$(( (now_epoch - last_epoch) / 86400 ))

  # 최근 30일 데이터 (전체 실행만, total ≥ min_total)
  local cutoff=$(date -j -v-30d "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
  local rates_30d=$(awk -F',' -v cutoff="$cutoff" -v rate_field="$rate_field" -v tf="$total_field" -v m="$min_total" '
    NR > 1 && $1 >= cutoff && $rate_field != "" && $tf+0 >= m+0 { print $rate_field }
  ' "$file")

  local n_30d=$(echo "$rates_30d" | grep -cv "^$")
  if [ "$n_30d" -eq 0 ]; then
    printf "  ⚠️ WARN %s: 30일 내 전체 실행 (total ≥ %s) 없음 (last=%s, stale %d일)\n" "$label" "$min_total" "$last_ts" "$stale_days"
    return 1
  fi

  local mean_30d=$(echo "$rates_30d" | awk '{s+=$1} END {printf "%.4f", s/NR}')

  # 최근 7일
  local cutoff_7=$(date -j -v-7d "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
  local rates_7d=$(awk -F',' -v cutoff="$cutoff_7" -v rate_field="$rate_field" -v tf="$total_field" -v m="$min_total" '
    NR > 1 && $1 >= cutoff && $rate_field != "" && $tf+0 >= m+0 { print $rate_field }
  ' "$file")
  local n_7d=$(echo "$rates_7d" | grep -cv "^$")
  local mean_7d="?"
  if [ "$n_7d" -gt 0 ]; then
    mean_7d=$(echo "$rates_7d" | awk '{s+=$1} END {printf "%.4f", s/NR}')
  fi

  # 최근 10회 전체 실행 중 FAIL 횟수 (rate < 1.0)
  local fail_recent=$(awk -F',' -v rate_field="$rate_field" -v tf="$total_field" -v m="$min_total" '
    NR > 1 && $tf+0 >= m+0 { print $rate_field }
  ' "$file" | tail -10 | awk '$1 != "" && $1+0 < 1.0 { f++ } END { print (f ? f : 0) }')

  # 추세 판정
  local status="PASS"
  local color=""
  local reason=""

  if [ "$stale_days" -gt 7 ]; then
    status="FAIL"; reason="stale ${stale_days}일"
  else
    # mean_30d 비교 (awk로 부동소수 비교)
    local mean_check=$(awk -v m="$mean_30d" 'BEGIN { if (m >= 0.95) print "ok"; else if (m >= 0.85) print "warn"; else print "fail" }')
    case "$mean_check" in
      fail) status="FAIL"; reason="30일 평균 $mean_30d < 0.85" ;;
      warn) status="WARN"; reason="30일 평균 $mean_30d (0.85~0.95)" ;;
      ok)
        # slope 검사: 7일 mean < 30일 mean (회귀 추세)
        if [ "$mean_7d" != "?" ]; then
          local slope_check=$(awk -v m7="$mean_7d" -v m30="$mean_30d" 'BEGIN { print (m7+0 < m30+0) ? "down" : "up" }')
          if [ "$slope_check" = "down" ]; then
            status="WARN"; reason="회귀 추세 (7일 $mean_7d < 30일 $mean_30d)"
          fi
        fi
        # 최근 10회 FAIL ≥ 3 → 회귀 빈도 높음
        if [ "$status" = "PASS" ] && [ "$fail_recent" -ge 3 ]; then
          status="WARN"; reason="최근 10회 FAIL=$fail_recent (회귀 빈도 ≥ 30%)"
        fi
        ;;
    esac
  fi

  printf "  %s %s: 30일 mean=%s (n=%d) / 7일 mean=%s (n=%d) / 최근10 FAIL=%s / stale=%d일 %s\n" \
    "$status" "$label" "$mean_30d" "$n_30d" "$mean_7d" "$n_7d" "$fail_recent" "$stale_days" \
    "${reason:+— $reason}"

  case "$status" in
    PASS) return 0 ;;
    WARN) return 1 ;;
    FAIL) return 2 ;;
  esac
}

REG_RC=0
EDD_RC=0

analyze "regression" "$ROOT/eval/results/baseline.csv" 5 2 10 || REG_RC=$?
analyze "edd       " "$ROOT/eval/results/edd-baseline.csv" 8 5 5 || EDD_RC=$?

echo ""
echo "── 종합 ──"

# 가장 나쁜 상태로 종합 판정
WORST=$(( REG_RC > EDD_RC ? REG_RC : EDD_RC ))
case "$WORST" in
  0) echo "✅ PASS — 회귀/EDD 모두 안정"; RESULT_TAG="PASS"; RC=0 ;;
  1) echo "⚠️ WARN — 추세 주의 (조기 회귀 신호 가능)"; RESULT_TAG="WARN"; RC=1 ;;
  2) echo "❌ FAIL — 회귀/stale 발생"; RESULT_TAG="FAIL"; RC=2 ;;
esac

# sensor-log 박제 (2026-05-02 H8)
bash "$(dirname "$0")/sensor-log.sh" "sensor-eval-trend" "$RESULT_TAG" "reg_rc=$REG_RC edd_rc=$EDD_RC worst=$WORST" 2>/dev/null || true
exit $RC
