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
#
# 게이트 정책 (2026-06-01 강제형 배선 — P1 eval 게이트 실효화):
#   [HARD-BLOCK] must-pass task가 1건이라도 FAIL → commit 차단 (exit 1)
#     - known-accepted allowlist(eval/known-accepted-fails.txt)에 등재된 task id 는 제외
#       (cross-domain real FAIL 추적용 — 사유+task id 1줄씩, '#' 주석 허용). 현재 등재 0건.
#   [REGRESSION] 직전 baseline 대비 통과율 5%p 초과 하락 → 차단 (이중 방어, 보존)
#   [BYPASS] --force 긴급 우회

set -u

PROJECT_ROOT="/Users/sokol/Git/ProjectGrimoire"
EVAL_DIR="$PROJECT_ROOT/eval"
BASELINE_FILE="$EVAL_DIR/results/baseline.csv"
ALLOWLIST_FILE="$EVAL_DIR/known-accepted-fails.txt"
TOLERANCE=0.05

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
  esac
done

echo "=== eval-precommit ($(date +'%H:%M:%S')) ==="

# eval-runner 실행 (전체 task 1회 — quiet)
bash "$EVAL_DIR/scripts/eval-runner.sh" --quiet
LATEST_RATE=$(tail -1 "$BASELINE_FILE" | awk -F, '{print $5}')
echo "최신 통과율: $LATEST_RATE"

# ── [HARD-BLOCK] must-pass FAIL 절대 게이트 ──
# 방금 실행이 적재한 가장 최근 결과 디렉토리의 details.jsonl 에서 FAIL task id 집계.
LATEST_DETAILS=$(ls -td "$EVAL_DIR"/results/2026-*/ 2>/dev/null | head -1)
LATEST_DETAILS="${LATEST_DETAILS}details.jsonl"

if [ ! -f "$LATEST_DETAILS" ]; then
  echo "⚠️ eval 결과 details.jsonl 없음 — 게이트 판정 불가. commit 차단 (안전측)"
  [ "$FORCE" -eq 1 ] && { echo "[FORCE] 우회"; exit 0; }
  exit 1
fi

# FAIL task id 목록 (중복 제거) — allowlist 제외 후 잔여 FAIL 집계
BLOCKING=$(python3 - "$LATEST_DETAILS" "$ALLOWLIST_FILE" <<'PYEOF'
import json, os, sys
details_path, allowlist_path = sys.argv[1], sys.argv[2]

allow = set()
if os.path.exists(allowlist_path):
    with open(allowlist_path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            allow.add(line.split()[0])  # 첫 토큰 = task id, 나머지는 사유

fail_ids = []
seen = set()
with open(details_path, encoding='utf-8') as f:
    for line in f:
        try:
            d = json.loads(line)
        except Exception:
            continue
        tid = d.get('id')
        if tid is None or tid in seen:
            continue
        seen.add(tid)
        if not d.get('pass'):
            fail_ids.append(tid)

blocking = [t for t in fail_ids if t not in allow]
accepted = [t for t in fail_ids if t in allow]
# stderr 로 진단 정보, stdout 으로 blocking 목록(게이트 판정용)
print(f"[gate] 전체 FAIL={len(fail_ids)} / known-accepted={len(accepted)} {accepted} / blocking={len(blocking)} {blocking}", file=sys.stderr)
for t in blocking:
    print(t)
PYEOF
)
GATE_STDERR=$?  # python exit (0 정상)
# 진단 라인은 위 heredoc 의 stderr 가 콘솔로 직접 흐름. BLOCKING 변수엔 blocking task id만.

if [ -n "$BLOCKING" ]; then
  echo "⛔ [HARD-BLOCK] must-pass task FAIL 감지:"
  echo "$BLOCKING" | sed 's/^/    - /'
  echo "  → 코드 회귀이면 수정, task 가 stale 이면 현행화, cross-domain real FAIL 이면 $ALLOWLIST_FILE 에 사유와 함께 등재."
  if [ "$FORCE" -eq 1 ]; then
    echo "[FORCE] commit 진행 (--force 사용) — 게이트 우회 박제"
    exit 0
  fi
  echo "commit 차단."
  exit 1
fi

# ── [REGRESSION] 직전 대비 통과율 하락 게이트 (이중 방어, 보존) ──
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

echo "[PASS] eval-precommit 통과 (must-pass 0 FAIL + baseline 정합)"
exit 0
