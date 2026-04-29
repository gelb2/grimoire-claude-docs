#!/usr/bin/env bash
# eval-precommit.sh — claude-docs 또는 메타 commit 전 eval 회귀 검증
#
# 사용 옵션:
#   1) 사용자 수동 호출: bash eval/scripts/eval-precommit.sh
#   2) git hook 통합: ln -sf ../../eval/scripts/eval-precommit.sh .git/hooks/pre-commit
#   3) Makefile target: make eval (별도 정의 시)
#
# 정책:
#   - 회귀 임계값 0.05 (5%p 이상 baseline 대비 하락 시 commit 차단)
#   - 첫 실행은 baseline 박제만, 비교 안 함
#   - --force 옵션으로 우회 가능 (긴급 시)
#
# 책 Ch 15 CI/CD 통합 정합 (regression-tolerance 0.05) — GitHub Actions 미사용 결정에 따라 pre-commit/manual 통합

set -u

PROJECT_ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
EVAL_DIR="$PROJECT_ROOT/eval"
BASELINE_FILE="$EVAL_DIR/results/baseline.csv"
TOLERANCE=0.05

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
  esac
done

echo "=== eval-precommit ($(date +'%H:%M:%S')) ==="

# eval-runner 실행
bash "$EVAL_DIR/scripts/eval-runner.sh" --quiet
LATEST_RATE=$(tail -1 "$BASELINE_FILE" | awk -F, '{print $5}')
echo "최신 통과율: $LATEST_RATE"

# baseline 비교 (이전 실행과)
if [ -f "$BASELINE_FILE" ]; then
  PREV_RATE=$(tail -2 "$BASELINE_FILE" | head -1 | awk -F, '{print $5}')
  if [ -n "$PREV_RATE" ] && [ "$PREV_RATE" != "pass_rate" ]; then
    REGRESSION=$(python3 -c "print(round(float('$PREV_RATE') - float('$LATEST_RATE'), 4))")
    echo "이전 통과율: $PREV_RATE / 회귀: $REGRESSION"

    if python3 -c "exit(0 if float('$REGRESSION') > $TOLERANCE else 1)"; then
      echo "⚠️ 회귀 감지: $REGRESSION > tolerance $TOLERANCE"
      if [ "$FORCE" -eq 1 ]; then
        echo "[FORCE] commit 진행 (--force 사용)"
        exit 0
      fi
      echo "commit 차단. 회귀 원인 조사 + 수정 후 재시도하거나 --force 사용"
      exit 1
    fi
  fi
fi

echo "[PASS] eval-precommit 통과 (baseline 정합)"
exit 0
