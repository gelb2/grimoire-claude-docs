#!/bin/bash
# generate-sensor-tasks.sh — sensor → eval task 자동 wrap (책 Ch 15 EDD)
#
# 13 sensors 중 이미 eval task로 wrap된 것은 SKIP, 누락 sensor만 단순 task 생성.
# 생성 위치: eval/tasks/auto-{sensor-name}.json (기존 수동 task와 구분)
#
# 동작:
#   - dry-run (기본): 누락 sensor 목록만 출력, task 파일 생성 안 함
#   - apply: 실제로 task json 생성
#
# 카테고리 매핑 (sensor → category):
#   - secret/security/auth/credit → security
#   - docs/migration → api_contract
#   - cost → cost_zero
#   - 그 외 → convention
#
# Threshold: 0.95 (단순 sensor는 결정적이라 강한 임계 가능)
#
# 사용:
#   bash eval/scripts/generate-sensor-tasks.sh           # dry-run
#   bash eval/scripts/generate-sensor-tasks.sh apply     # 실제 생성

set +u
ROOT="/Users/sokol/Git/ProjectGrimoire"
TASKS_DIR="$ROOT/eval/tasks"
APPLY="${1:-dry-run}"

# 카테고리 매핑
get_category() {
  case "$1" in
    secret-leak|security-gate|credit-atomicity) echo "security" ;;
    docs-sync|deploy-drift) echo "api_contract" ;;
    cost-margin) echo "cost_zero" ;;
    *) echo "convention" ;;
  esac
}

CREATED=0
SKIPPED=0
echo "=== sensor → eval task 자동 wrap (mode: $APPLY) ==="
echo ""

for sensor_path in "$ROOT"/.claude/scripts/sensor-*.sh; do
  sensor_name=$(basename "$sensor_path" .sh | sed 's/^sensor-//')

  # 이미 wrap된 sensor인가
  if grep -l "sensor-${sensor_name}" "$TASKS_DIR"/*.json >/dev/null 2>&1; then
    SKIPPED=$((SKIPPED+1))
    continue
  fi

  # 카테고리 결정
  category=$(get_category "$sensor_name")

  # auto-* task 파일 경로
  auto_file="$TASKS_DIR/auto-sensor-${sensor_name}.json"

  if [ "$APPLY" = "apply" ]; then
    cat > "$auto_file" <<JSON
{
  "id": "auto-sensor-${sensor_name}",
  "name": "[자동 생성] sensor-${sensor_name} PASS/WARN 회귀 보호 (FAIL만 차단)",
  "category": "$category",
  "source_session": "20260430 #10 F1 — generate-sensor-tasks.sh 자동 wrap",
  "prompt": "sensor-${sensor_name}.sh 가 FAIL이 아닌가? exit 0 (PASS) 또는 exit 1/2 (WARN)는 허용. exit ≥3 (FAIL)만 차단. 자동 생성 task — 새 sensor 추가 시 generator 재실행으로 task 자동 보충.",
  "eval_criteria": [
    {"type": "command", "command": "bash .claude/scripts/sensor-${sensor_name}.sh; ec=\$?; [ \$ec -le 2 ]", "desc": "sensor-${sensor_name}.sh exit ≤2 (PASS/WARN 허용)"}
  ],
  "threshold": 1.0,
  "runs": 1,
  "auto_generated": true
}
JSON
    echo "  ✨ 생성 sensor-${sensor_name} → auto-sensor-${sensor_name}.json (category=$category)"
    CREATED=$((CREATED+1))
  else
    echo "  📋 누락 sensor-${sensor_name} → 생성 후보 (category=$category)"
    CREATED=$((CREATED+1))
  fi
done

echo ""
echo "── 종합 ──"
echo "이미 wrap: $SKIPPED 개"
if [ "$APPLY" = "apply" ]; then
  echo "신규 생성: $CREATED 개"
  if [ "$CREATED" -gt 0 ]; then
    echo ""
    echo "▶ 다음 단계: bash eval/scripts/eval-runner.sh 로 회귀 검증"
  fi
else
  echo "생성 후보: $CREATED 개"
  echo ""
  echo "▶ 실제 생성: bash eval/scripts/generate-sensor-tasks.sh apply"
fi
