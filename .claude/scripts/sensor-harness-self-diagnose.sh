#!/usr/bin/env bash
# sensor-harness-self-diagnose.sh — 책 Ch 23 자가진단 7질문 자동화
#
# 책 Ch 23 권장: "3 이상 '아니오'면 쇠퇴 경로 — 즉시 보강"
# 우리 운영: 매주 자동 실행 + Q4 사용자 보류 결정으로 영구 SKIP (6 질문만 활성)
#
# 7 질문 매핑:
#   Q1 작업 시간 70%+ 실제 구현?       → sensor-orchestration-ratio (ratio ≥ 0.5)
#   Q2 CLAUDE.md ≤100줄?               → wc -l (≤ 80, 우리 임계)
#   Q3 하네스 수정 효과 수치?          → sensor-eval-trend (regression mean ≥ 0.95)
#   Q4 모델 개선 여지 측정?            → 사용자 보류 (영구 SKIP)
#   Q5 CLAUDE.md ↔ 코드 일치?          → instructions-drift-check (exit 0)
#   Q6 태스크 비용 인지?               → cost-tracker.jsonl (≥ 1건)
#   Q7 하네스 변경 리뷰?               → sensor-shared-contracts (PASS)
#
# Exit 0: 활성 6/6 PASS / Q4 SKIP — 건강 경로
# Exit 1: 1~2건 ❌ — 보강 권장
# Exit 2: 3건 이상 ❌ — 책 Ch 23 쇠퇴 경로 ALERT

set +u

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
PASS=0
FAIL=0
SKIP=0
RESULTS=()

check() {
  local q="$1"
  local label="$2"
  local result="$3"  # PASS / FAIL / SKIP
  local detail="$4"
  RESULTS+=("Q$q: $result | $label | $detail")
  case "$result" in
    PASS) PASS=$((PASS+1)) ;;
    FAIL) FAIL=$((FAIL+1)) ;;
    SKIP) SKIP=$((SKIP+1)) ;;
  esac
}

echo "=== sensor-harness-self-diagnose (책 Ch 23 자가진단 7질문) ==="
echo ""

# Q1: 작업 시간 70%+ 실제 구현 (sensor-orchestration-ratio)
RATIO_FILE="$ROOT/.claude/state/orchestration-ratio.jsonl"
if [ -s "$RATIO_FILE" ]; then
  RATIO=$(tail -1 "$RATIO_FILE" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('orchestration_ratio', 0))" 2>/dev/null || echo 0)
  if python3 -c "exit(0 if $RATIO >= 0.5 else 1)" 2>/dev/null; then
    check 1 "구현 시간 비율" "PASS" "ratio=$RATIO ≥ 0.5"
  else
    check 1 "구현 시간 비율" "FAIL" "ratio=$RATIO < 0.5 (메인 직접 작업이 너무 많음)"
  fi
else
  check 1 "구현 시간 비율" "FAIL" "orchestration-ratio.jsonl 없음"
fi

# Q2: CLAUDE.md ≤80줄 (우리 임계)
LINES=$(wc -l < "$ROOT/CLAUDE.md" | tr -d ' ')
if [ "$LINES" -le 80 ]; then
  check 2 "CLAUDE.md 크기" "PASS" "${LINES}줄 ≤ 80"
else
  check 2 "CLAUDE.md 크기" "FAIL" "${LINES}줄 > 80 (instruction degradation 위험)"
fi

# Q3: 하네스 수정 효과 수치 (sensor-eval-trend or baseline.csv)
BASELINE="$ROOT/eval/results/baseline.csv"
if [ -s "$BASELINE" ]; then
  RECENT_PASS=$(tail -10 "$BASELINE" | awk -F, 'NR>0 {sum+=$5; n+=1} END {if (n>0) print sum/n; else print 0}')
  if python3 -c "exit(0 if $RECENT_PASS >= 0.95 else 1)" 2>/dev/null; then
    check 3 "하네스 수정 효과 수치" "PASS" "최근 10회 mean=$RECENT_PASS ≥ 0.95"
  else
    check 3 "하네스 수정 효과 수치" "FAIL" "최근 10회 mean=$RECENT_PASS < 0.95"
  fi
else
  check 3 "하네스 수정 효과 수치" "FAIL" "baseline.csv 없음"
fi

# Q4: 모델 개선 여지 측정 — 사용자 보류 (영구 SKIP)
check 4 "모델 개선 여지 측정" "SKIP" "사용자 명시 보류 (외부 API 의존, 0-1 결정)"

# Q5: CLAUDE.md ↔ 코드 일치 (instructions-drift-check)
if bash "$ROOT/.claude/scripts/instructions-drift-check.sh" >/dev/null 2>&1; then
  check 5 "CLAUDE.md ↔ 코드 일치" "PASS" "drift sensor exit 0"
else
  check 5 "CLAUDE.md ↔ 코드 일치" "FAIL" "drift sensor 실패"
fi

# Q6: 태스크 비용 인지 (cost-tracker.jsonl)
COST_LOG="$ROOT/.claude/state/cost-tracker.jsonl"
if [ -s "$COST_LOG" ]; then
  COUNT=$(wc -l < "$COST_LOG" | tr -d ' ')
  check 6 "태스크 비용 인지" "PASS" "cost-tracker.jsonl ${COUNT}건 박제"
else
  check 6 "태스크 비용 인지" "FAIL" "cost-tracker.jsonl 없음 (BN-#4 미실행)"
fi

# Q7: 하네스 변경 리뷰 (sensor-shared-contracts)
if bash "$ROOT/.claude/scripts/sensor-shared-contracts.sh" >/dev/null 2>&1; then
  check 7 "하네스 변경 리뷰" "PASS" "shared-contracts sensor PASS"
else
  check 7 "하네스 변경 리뷰" "FAIL" "shared-contracts sensor 실패"
fi

# 출력
echo "── 7 질문 ──"
for r in "${RESULTS[@]}"; do
  echo "  $r"
done

# 종합
echo ""
echo "── 종합 ──"
ACTIVE=$((PASS + FAIL))
echo "PASS: $PASS / FAIL: $FAIL / SKIP: $SKIP (활성 $ACTIVE / 총 7)"

# 책 Ch 23 판정
if [ "$FAIL" -ge 3 ]; then
  echo ""
  echo "🚨 책 Ch 23 쇠퇴 경로 ALERT — FAIL ${FAIL}건 ≥ 3 (즉시 보강 필요)"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-harness-self-diagnose" "FAIL" "PASS=$PASS FAIL=$FAIL SKIP=$SKIP" 2>/dev/null || true
  exit 2
elif [ "$FAIL" -ge 1 ]; then
  echo ""
  echo "⚠️ FAIL ${FAIL}건 — 보강 권장 (3건 미만이라 쇠퇴 경로 아님)"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-harness-self-diagnose" "WARN" "PASS=$PASS FAIL=$FAIL SKIP=$SKIP" 2>/dev/null || true
  exit 1
else
  echo ""
  echo "✅ 활성 $ACTIVE/$ACTIVE PASS — 건강 경로 (책 Ch 23 정합)"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-harness-self-diagnose" "PASS" "PASS=$PASS FAIL=$FAIL SKIP=$SKIP" 2>/dev/null || true
  exit 0
fi
