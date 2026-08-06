#!/usr/bin/env bash
# eval-runner.sh — ProjectGrimoire Eval 실행기 (책 Ch 15 EDD 차용)
#
# 두 모드 지원:
#   - regression (default): runs=1, threshold=1.0 — 코드 상태 결정적 검증
#   - edd: runs=N (default 10), category별 threshold — 확률적 평가 (LLM-as-Judge 결합 가능)
#
# 사용:
#   bash eval/scripts/eval-runner.sh                              # regression mode (default)
#   bash eval/scripts/eval-runner.sh --mode=edd                   # EDD mode (runs=10)
#   bash eval/scripts/eval-runner.sh --mode=edd --runs=5          # EDD mode with custom runs
#   bash eval/scripts/eval-runner.sh tasks/01-...json             # 단일 실행
#   bash eval/scripts/eval-runner.sh --quiet                      # PASS 시 출력 없음
#   bash eval/scripts/eval-runner.sh --strict                     # 첫 FAIL 시 exit 1
#   bash eval/scripts/eval-runner.sh --llm-judge                  # LLM 채점 활성 (EDD 모드만, cost-accountant 가이드라인 준수)
#
# Category별 EDD threshold (cost-accountant 권장):
#   - security        : 0.95+ (실패 1건 비용 극도)
#   - cost_zero       : 0.95+ (§0 위반 위험)
#   - visual_canon    : 0.90+ (사슴악마 정본)
#   - author_content  : 1.00 (작가 본문 보호 — 무관용)
#   - type_safety     : 0.90+ (코드 결정적)
#   - convention      : 0.80~0.90 (코드 스타일)
#   - api_contract    : 0.80~0.90
#   - edge_case       : 0.70~0.80 (경로 다수)
#   - test_coverage   : 0.60~0.70 (부분 성공 가치)
#
# LLM-as-Judge 비용 가드 (cost-accountant 위임 결과):
#   - LLM 태스크 비율 ≤ 35% (20개 중 7개 이하)
#   - 일일 EDD 실행 ≤ 2회
#   - 월간 LLM 채점 비용 ≤ ₩50,000
#   - 일일 알림 임계 ₩2,000
#
# 출력:
#   - eval/results/baseline.csv (시계열)
#   - eval/results/edd-baseline.csv (EDD 모드 시계열)
#   - eval/results/{timestamp}/summary.json + details.jsonl

set +u

PROJECT_ROOT="/Users/sokol/Git/ProjectGrimoire"
EVAL_DIR="$PROJECT_ROOT/eval"
TASKS_DIR="$EVAL_DIR/tasks"
TASKS_EDD_DIR="$EVAL_DIR/tasks-edd"
RESULTS_DIR="$EVAL_DIR/results/$(date +'%Y-%m-%d-%H-%M-%S')"
BASELINE_FILE="$EVAL_DIR/results/baseline.csv"
EDD_BASELINE_FILE="$EVAL_DIR/results/edd-baseline.csv"
GRADE_PY="$EVAL_DIR/scripts/grade.py"
GRADE_LLM_PY="$EVAL_DIR/scripts/grade-llm.py"

# baseline.csv rolling cap (2026-06-02 P2: 무한누적 차단).
# 매 commit(pre-commit→eval-precommit→eval-runner)마다 1행 append 되던 무한증가를
# "헤더 1행 + 최근 BASELINE_CAP 데이터행" rolling window 로 제한.
# - 회귀 판정(eval-precommit tail-1=이번/tail-2=직전) 의미 보존 (마지막 행들 그대로).
# - sensor-eval-trend 30일 추세 모수도 충분히 보존 (cap=100 ≈ 수일~2주분).
# - per-run 전체 이력은 eval/results/{timestamp}/ summary.json+details.jsonl 에 영구 보존.
BASELINE_CAP=100

# trim_baseline <csv_file> — 헤더 보존, 최근 BASELINE_CAP 데이터행만 유지 (멱등).
trim_baseline() {
  local f="$1"
  [ -f "$f" ] || return 0
  local data_lines
  data_lines=$(( $(wc -l < "$f") - 1 ))
  [ "$data_lines" -le "$BASELINE_CAP" ] && return 0
  local tmp="$f.trim.$$"
  { head -1 "$f"; tail -n +2 "$f" | tail -n "$BASELINE_CAP"; } > "$tmp" && mv "$tmp" "$f"
}

mkdir -p "$RESULTS_DIR"

QUIET=0
STRICT=0
SINGLE_TASK=""
MODE="regression"
RUNS=1
LLM_JUDGE=0
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --strict) STRICT=1 ;;
    --mode=edd) MODE="edd"; RUNS=10 ;;
    --mode=regression) MODE="regression"; RUNS=1 ;;
    --runs=*) RUNS="${arg#--runs=}" ;;
    --llm-judge) LLM_JUDGE=1 ;;
    tasks/*) SINGLE_TASK="$EVAL_DIR/$arg" ;;
    *.json) SINGLE_TASK="$arg" ;;
  esac
done

# EDD 모드 외 LLM 채점 차단 (가드)
if [ "$LLM_JUDGE" -eq 1 ] && [ "$MODE" != "edd" ]; then
  echo "[WARN] --llm-judge는 --mode=edd 와 함께만 사용 (cost-accountant 가이드라인). LLM 채점 비활성"
  LLM_JUDGE=0
fi

[ "$QUIET" -eq 0 ] && echo "=== ProjectGrimoire Eval [mode=$MODE, runs=$RUNS, llm-judge=$LLM_JUDGE] ($(date +'%Y-%m-%d %H:%M:%S')) ==="
[ "$QUIET" -eq 0 ] && echo "결과 디렉토리: $RESULTS_DIR"
[ "$QUIET" -eq 0 ] && echo ""

PASS_TASKS=0
FAIL_TASKS=0
TOTAL_TASKS=0

# task 목록 결정 (regression: tasks/, EDD: tasks/+tasks-edd/)
if [ -n "$SINGLE_TASK" ]; then
  TASK_FILES="$SINGLE_TASK"
elif [ "$MODE" = "edd" ]; then
  TASK_FILES=$(ls "$TASKS_DIR"/*.json "$TASKS_EDD_DIR"/*.json 2>/dev/null | sort)
else
  TASK_FILES=$(ls "$TASKS_DIR"/*.json | sort)
fi

# 각 task 실행 (EDD 모드는 RUNS회 반복, regression은 1회)
for task_file in $TASK_FILES; do
  TOTAL_TASKS=$((TOTAL_TASKS+1))
  task_name=$(basename "$task_file" .json)

  [ "$QUIET" -eq 0 ] && echo "▶ [$task_name]"

  # EDD 모드: RUNS회 반복 + 통과율로 task pass 판정
  RUN_PASS=0
  for run_i in $(seq 1 "$RUNS"); do
    # grade.py 호출 (또는 LLM 결합)
    if [ "$LLM_JUDGE" -eq 1 ] && [ -x "$GRADE_LLM_PY" ]; then
      result=$(python3 "$GRADE_LLM_PY" "$task_file" "$PROJECT_ROOT" 2>&1)
    else
      result=$(python3 "$GRADE_PY" "$task_file" "$PROJECT_ROOT" 2>&1)
    fi
    exit_code=$?
    echo "$result" >> "$RESULTS_DIR/details.jsonl"
    [ "$exit_code" -eq 0 ] && RUN_PASS=$((RUN_PASS+1))
  done

  # task별 pass 판정 (EDD: RUN_PASS/RUNS ≥ task threshold)
  if [ "$MODE" = "edd" ]; then
    # task의 threshold (default 0.8)
    TASK_THRESHOLD=$(python3 -c "
import json
with open('$task_file') as f:
    t = json.load(f)
# category별 default + task override
cat = t.get('category', '')
defaults = {
    'security': 0.95, 'cost_zero': 0.95, 'visual_canon': 0.90,
    'author_content': 1.00, 'type_safety': 0.90,
    'convention': 0.85, 'api_contract': 0.85,
    'edge_case': 0.75, 'test_coverage': 0.65,
}
print(t.get('edd_threshold', defaults.get(cat, 0.8)))
")
    RUN_RATE=$(python3 -c "print(round($RUN_PASS/$RUNS, 4))")
    if python3 -c "exit(0 if $RUN_RATE >= $TASK_THRESHOLD else 1)"; then
      PASS_TASKS=$((PASS_TASKS+1))
      [ "$QUIET" -eq 0 ] && echo "  ✅ PASS ($RUN_PASS/$RUNS = $RUN_RATE ≥ $TASK_THRESHOLD)"
    else
      FAIL_TASKS=$((FAIL_TASKS+1))
      [ "$QUIET" -eq 0 ] && echo "  ❌ FAIL ($RUN_PASS/$RUNS = $RUN_RATE < $TASK_THRESHOLD)"
      if [ "$STRICT" -eq 1 ]; then
        echo "[RESULT] FAIL (strict) — task $task_name EDD 임계 미달"
        exit 1
      fi
    fi
  else
    # regression: 단일 실행 결과
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

# TaskFlow 5차원 가중 점수 집계 (책 Ch 15, 묶음 II)
if [ "$QUIET" -eq 0 ] && [ -f "$RESULTS_DIR/details.jsonl" ]; then
  WEIGHTED_SUMMARY=$(python3 <<PYEOF
import json
from collections import defaultdict

dim_total = defaultdict(float)
dim_earned = defaultdict(float)
overall_total = 0.0
overall_earned = 0.0
n = 0

with open("$RESULTS_DIR/details.jsonl") as f:
    for line in f:
        try:
            d = json.loads(line)
        except:
            continue
        ws = d.get('weighted_score')
        if ws is None:
            continue
        n += 1
        overall_total += 1.0
        overall_earned += ws
        for dim, score in d.get('dim_scores', {}).items():
            dim_total[dim] += 1.0
            dim_earned[dim] += score

if n > 0:
    print(f"가중 점수 (TaskFlow 5차원): {round(overall_earned/overall_total, 4)} (n={n})")
    for dim in ['functional', 'code_quality', 'performance', 'security', 'ux']:
        if dim in dim_total:
            print(f"  - {dim:12} : {round(dim_earned[dim]/dim_total[dim], 4)} (n={int(dim_total[dim])})")
PYEOF
)
  if [ -n "$WEIGHTED_SUMMARY" ]; then
    echo ""
    echo "$WEIGHTED_SUMMARY"
  fi
fi

# baseline.csv 적재 (모드별 분리, SINGLE_TASK는 skip — NEW-6: 노이즈 회피)
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
mkdir -p "$EVAL_DIR/results"
if [ -n "$SINGLE_TASK" ]; then
  # 단일 task 디버깅 — baseline 적재 skip (sensor-eval-trend min_total 필터 대신 source 차단)
  [ "$QUIET" -eq 0 ] && echo "[skip] single-task 모드 — baseline.csv 적재 안 함"
elif [ "$MODE" = "edd" ]; then
  [ ! -f "$EDD_BASELINE_FILE" ] && echo "ts,mode,runs,llm,total,pass,fail,pass_rate" > "$EDD_BASELINE_FILE"
  echo "$TS,$MODE,$RUNS,$LLM_JUDGE,$TOTAL_TASKS,$PASS_TASKS,$FAIL_TASKS,$PASS_RATE" >> "$EDD_BASELINE_FILE"
  trim_baseline "$EDD_BASELINE_FILE"
else
  [ ! -f "$BASELINE_FILE" ] && echo "ts,total,pass,fail,pass_rate" > "$BASELINE_FILE"
  echo "$TS,$TOTAL_TASKS,$PASS_TASKS,$FAIL_TASKS,$PASS_RATE" >> "$BASELINE_FILE"
  trim_baseline "$BASELINE_FILE"
fi

# summary.json
cat > "$RESULTS_DIR/summary.json" <<JSON
{
  "ts": "$TS",
  "mode": "$MODE",
  "runs": $RUNS,
  "llm_judge": $LLM_JUDGE,
  "total": $TOTAL_TASKS,
  "pass": $PASS_TASKS,
  "fail": $FAIL_TASKS,
  "pass_rate": $PASS_RATE,
  "results_dir": "$RESULTS_DIR"
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
