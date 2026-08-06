#!/usr/bin/env bash
# adversarial-retry-handler.sh — Pre-commit FAIL 시 자동 회복 (max 2 iterations)
#
# ng/adversarial-review의 Bounded Verification Loop 패턴 차용 (Fowler Resilience).
# 책 Ch 21 Correct 기둥 강화 + Ch 23 안티패턴 #6 비용 블랙홀 방어.
#
# 사용:
#   bash adversarial-retry-handler.sh           # pre-commit 실패 후 자동 발동
#   bash adversarial-retry-handler.sh --dry-run # 시뮬만 (실제 fix 안 함)
#
# 자동 fix 영역 (결정적 — 안전):
#   1. drift §14.X 카운트 → update-harness-inventory --apply
#   2. auto-sensor-* 미생성 → generate-sensor-tasks.sh apply
#   3. baseline.csv 단순 갱신 (regression 자동 실행 결과)
#   4. .claude/state/*.jsonl 누적 (sensor-log 자동 박제)
#
# Cost Gate Scoring 명시 (2026-05-03 묶음 CC, ng/adversarial-review 차용):
#   - Score ≤ 0: Report만 생성 (LLM 스킵) — 본 retry-handler는 항상 Score ≤ 0 모드 (외부 API 0)
#   - Score 1~4 (Sonnet 2 agents): LLM 호출 동반 → 사용자 0-1 결정 위반 (보류)
#   - Score ≥ 5 (Sonnet+Opus 4 agents): LLM 호출 동반 → 사용자 0-1 결정 위반 (보류)
#
# 우리 운영: 항상 Score ≤ 0 (외부 API 0) — 결정적 자동 fix만, LLM Optimizer/Skeptic은 Phase δ 미해소
#
# 자동 fix 금지 영역 (의미 있는 코드 변경 — 사용자 승인 필요):
#   - 7 에이전트 .md 수정
#   - shared-contracts.md 수정
#   - red-team-constitution.md 수정
#   - server/web 코드 변경
#   - sensor 자체 로직 변경
#
# Exit:
#   0 — 1차 통과 또는 자동 fix 후 2차 통과 (commit 가능)
#   1 — 2회 시도에도 실패 (사용자 검토 필요)
#   2 — 자동 fix 영역이 아닌 위반 발견 (사용자 직접 수정 필요)

set +u

ROOT="/Users/sokol/Git/ProjectGrimoire"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

echo "=== adversarial-retry-handler (max 2 iterations, ng/adversarial-review 패턴) ==="
echo ""

# 1차 시도 — adversarial sensor 실행
echo "── 1차 시도: sensor-adversarial-pre-commit ──"
bash "$ROOT/.claude/scripts/sensor-adversarial-pre-commit.sh" > /tmp/adv-1.log 2>&1
ADV_RC=$?
tail -5 /tmp/adv-1.log

if [ "$ADV_RC" -eq 0 ]; then
  echo ""
  echo "✅ 1차 통과 — 추가 작업 불필요"
  exit 0
elif [ "$ADV_RC" -eq 1 ]; then
  echo ""
  echo "⚠️ WARN — 검토 권장 (commit 허용, 자동 fix 시도 안 함)"
  exit 0
fi

# FAIL 분기 — 자동 fix 가능 영역 식별
echo ""
echo "── FAIL 분석: 자동 fix 가능 영역 식별 ──"

AUTO_FIXED=0
NEEDS_USER=0

# Fix 1 — drift 자동 갱신
echo "  [1/4] drift 자동 갱신 (update-harness-inventory --apply)..."
if [ "$DRY_RUN" -eq 0 ]; then
  if bash "$ROOT/.claude/scripts/update-harness-inventory.sh" --apply >> /tmp/adv-fix.log 2>&1; then
    INV_FIXED=$(grep -c "✅ .*: .* → " /tmp/adv-fix.log 2>/dev/null); INV_FIXED=${INV_FIXED:-0}
    if [ "$INV_FIXED" -gt 0 ]; then
      echo "    ✅ drift ${INV_FIXED}건 자동 갱신"
      AUTO_FIXED=$((AUTO_FIXED + INV_FIXED))
    else
      echo "    (drift 없음)"
    fi
  fi
else
  echo "    [DRY-RUN] update-harness-inventory --apply 시뮬"
fi

# Fix 2 — auto-sensor-* 미생성 갱신
echo "  [2/4] auto-sensor wrap 자동 보충 (generate-sensor-tasks apply)..."
if [ "$DRY_RUN" -eq 0 ]; then
  GEN_OUT=$(bash "$ROOT/eval/scripts/generate-sensor-tasks.sh" apply 2>&1)
  GEN_NEW=$(echo "$GEN_OUT" | grep -c "✨ 생성" 2>/dev/null); GEN_NEW=${GEN_NEW:-0}
  if [ "$GEN_NEW" -gt 0 ]; then
    echo "    ✅ auto-sensor wrap ${GEN_NEW}건 신규 생성"
    AUTO_FIXED=$((AUTO_FIXED + GEN_NEW))
  else
    echo "    (이미 모두 wrap)"
  fi
else
  echo "    [DRY-RUN] generate-sensor-tasks apply 시뮬"
fi

# Fix 3 — baseline.csv는 자동 갱신 (regression 실행 시)
echo "  [3/4] baseline.csv 갱신 (regression 자동 실행)..."
if [ "$DRY_RUN" -eq 0 ]; then
  bash "$ROOT/eval/scripts/eval-runner.sh" --quiet > /tmp/adv-eval.log 2>&1
  EVAL_RC=$?
  if [ "$EVAL_RC" -eq 0 ]; then
    echo "    ✅ regression PASS + baseline.csv 갱신"
    AUTO_FIXED=$((AUTO_FIXED + 1))
  else
    echo "    ⚠️ regression FAIL — 자동 fix 영역 외"
    NEEDS_USER=$((NEEDS_USER + 1))
  fi
else
  echo "    [DRY-RUN] eval-runner 시뮬"
fi

# Fix 4 — sensor-log jsonl은 sensor 호출 시 자동 박제 (별도 액션 X)
echo "  [4/4] sensor-log jsonl 자동 박제 (sensor 호출 시 자동 — 액션 없음)"

echo ""
echo "── 자동 fix 결과: $AUTO_FIXED 건 fix / $NEEDS_USER 건 사용자 필요 ──"

# 자동 fix 결과로 NEEDS_USER 발생 시 즉시 종료
if [ "$NEEDS_USER" -gt 0 ]; then
  echo ""
  echo "❌ 자동 fix 영역 외 위반 발견 — 사용자 직접 수정 필요:"
  echo "   1. /tmp/adv-1.log 확인 → FAIL principles 식별"
  echo "   2. 해당 영역 사용자 직접 수정"
  echo "   3. git add + commit 재시도"
  exit 2
fi

# AUTO_FIXED ≥ 1 → 2차 시도
if [ "$AUTO_FIXED" -gt 0 ]; then
  echo ""
  echo "── 2차 시도: sensor-adversarial-pre-commit 재실행 ──"
  bash "$ROOT/.claude/scripts/sensor-adversarial-pre-commit.sh" > /tmp/adv-2.log 2>&1
  ADV_RC2=$?
  tail -5 /tmp/adv-2.log

  if [ "$ADV_RC2" -le 1 ]; then
    echo ""
    echo "✅ 2차 통과 — commit 가능 (자동 fix 후 회복)"
    exit 0
  else
    echo ""
    echo "❌ 2차도 FAIL — 사용자 검토 필요 (max 2 iterations 도달)"
    echo "   /tmp/adv-2.log 확인 → 잔존 위반 사용자 직접 수정"
    exit 1
  fi
else
  echo ""
  echo "⚠️ 자동 fix 영역 0건 — 사용자 직접 수정 필요"
  echo "   /tmp/adv-1.log 확인 → FAIL principles 식별"
  exit 2
fi
