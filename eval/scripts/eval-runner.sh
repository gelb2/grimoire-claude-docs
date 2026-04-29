#!/usr/bin/env bash
# eval-runner.sh — ProjectGrimoire 회귀 Eval 실행기 (책 Ch 15 EDD 차용)
#
# 동작:
#   - eval/tasks/*.json 모두 또는 단일 task 실행
#   - 각 task의 eval_criteria 채점 (코드 grep / command exit / inventory_match 등)
#   - threshold 통과 여부 + 결과 jsonl 적재
#   - results/{timestamp}/ 디렉토리에 보고서 박제
#
# 사용:
#   bash eval/scripts/eval-runner.sh                         # 전체 실행
#   bash eval/scripts/eval-runner.sh tasks/01-...json        # 단일 실행
#   bash eval/scripts/eval-runner.sh --quiet                 # PASS 시 출력 없음
#   bash eval/scripts/eval-runner.sh --strict                # 첫 FAIL 시 exit 1
#
# 출력:
#   - eval/results/baseline.csv (시계열 누적)
#   - eval/results/{timestamp}/summary.json
#   - eval/results/{timestamp}/details.jsonl

set +u

PROJECT_ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
EVAL_DIR="$PROJECT_ROOT/eval"
TASKS_DIR="$EVAL_DIR/tasks"
RESULTS_DIR="$EVAL_DIR/results/$(date +'%Y-%m-%d-%H-%M-%S')"
BASELINE_FILE="$EVAL_DIR/results/baseline.csv"
GRADE_PY="$EVAL_DIR/scripts/grade.py"

mkdir -p "$RESULTS_DIR"

QUIET=0
STRICT=0
SINGLE_TASK=""
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --strict) STRICT=1 ;;
    tasks/*) SINGLE_TASK="$EVAL_DIR/$arg" ;;
    *.json) SINGLE_TASK="$arg" ;;
  esac
done

[ "$QUIET" -eq 0 ] && echo "=== ProjectGrimoire Eval ($(date +'%Y-%m-%d %H:%M:%S')) ==="
[ "$QUIET" -eq 0 ] && echo "결과 디렉토리: $RESULTS_DIR"
[ "$QUIET" -eq 0 ] && echo ""

PASS_TASKS=0
FAIL_TASKS=0
TOTAL_TASKS=0

# task 목록 결정
if [ -n "$SINGLE_TASK" ]; then
  TASK_FILES="$SINGLE_TASK"
else
  TASK_FILES=$(ls "$TASKS_DIR"/*.json | sort)
fi

# 각 task 실행
for task_file in $TASK_FILES; do
  TOTAL_TASKS=$((TOTAL_TASKS+1))
  task_name=$(basename "$task_file" .json)

  [ "$QUIET" -eq 0 ] && echo "▶ [$task_name]"

  # grade.py 호출 — task 채점
  result=$(python3 "$GRADE_PY" "$task_file" "$PROJECT_ROOT" 2>&1)
  exit_code=$?

  # 결과 적재
  echo "$result" >> "$RESULTS_DIR/details.jsonl"

  if [ "$exit_code" -eq 0 ]; then
    PASS_TASKS=$((PASS_TASKS+1))
    [ "$QUIET" -eq 0 ] && echo "$result" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(f'  ✅ PASS ({d[\"passed\"]}/{d[\"total\"]} criteria)')"
  else
    FAIL_TASKS=$((FAIL_TASKS+1))
    [ "$QUIET" -eq 0 ] && echo "$result" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(f'  ❌ FAIL ({d[\"passed\"]}/{d[\"total\"]} criteria)')
for c in d.get('criteria', []):
    if not c.get('pass'):
        print(f'    - [{c.get(\"type\")}] {c.get(\"desc\", \"\")[:80]}')
        if c.get('detail'):
            print(f'      → {c.get(\"detail\")[:120]}')
"
    if [ "$STRICT" -eq 1 ]; then
      echo "[RESULT] FAIL (strict) — task $task_name 실패"
      exit 1
    fi
  fi
done

# 종합 보고서
if [ "$TOTAL_TASKS" -gt 0 ]; then
  PASS_RATE=$(python3 -c "print(round($PASS_TASKS/$TOTAL_TASKS, 4))")
else
  PASS_RATE="0.0000"
fi

[ "$QUIET" -eq 0 ] && echo ""
[ "$QUIET" -eq 0 ] && echo "─── 종합 ───"
[ "$QUIET" -eq 0 ] && echo "PASS: $PASS_TASKS / TOTAL: $TOTAL_TASKS / FAIL: $FAIL_TASKS"
[ "$QUIET" -eq 0 ] && echo "통과율: $PASS_RATE"

# baseline.csv 적재
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
mkdir -p "$EVAL_DIR/results"
[ ! -f "$BASELINE_FILE" ] && echo "ts,total,pass,fail,pass_rate" > "$BASELINE_FILE"
echo "$TS,$TOTAL_TASKS,$PASS_TASKS,$FAIL_TASKS,$PASS_RATE" >> "$BASELINE_FILE"

# summary.json
cat > "$RESULTS_DIR/summary.json" <<JSON
{
  "ts": "$TS",
  "total": $TOTAL_TASKS,
  "pass": $PASS_TASKS,
  "fail": $FAIL_TASKS,
  "pass_rate": $PASS_RATE,
  "results_dir": "$RESULTS_DIR",
  "baseline_csv": "$BASELINE_FILE"
}
JSON

[ "$QUIET" -eq 0 ] && echo "[기록] baseline.csv + $RESULTS_DIR/{summary.json,details.jsonl}"

# Exit
if [ "$FAIL_TASKS" -gt 0 ]; then
  [ "$QUIET" -eq 0 ] && echo "[RESULT] FAIL — $FAIL_TASKS 태스크 실패"
  if [ "$STRICT" -eq 1 ]; then
    exit 1
  fi
  exit 0
fi

[ "$QUIET" -eq 0 ] && echo "[RESULT] PASS — 전체 통과"
exit 0
