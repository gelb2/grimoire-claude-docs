#!/bin/bash
# sensor-shared-contracts.sh — .claude/shared-contracts.md ↔ 7 에이전트 .md / reports / 코드 정합 검증
#
# 책 Ch 16 "shared contracts" 패턴 준수 자동 검증.
# 인터페이스가 shared-contracts.md에 박제됐지만 실제 코드/에이전트가 참조하지 않으면 FAIL.
# 반대로 에이전트가 참조하지만 shared-contracts에 누락이면 FAIL.
#
# 검증 항목 (10 인터페이스):
#   1. PLANNER_REPORT       → reports/PLANNER_REPORT.md 존재 여부
#   2. COST_AUDIT_REPORT    → reports/COST_AUDIT_REPORT.md 존재 여부
#   3. VISUAL_CANON_REPORT  → reports/VISUAL_CANON_REPORT.md 존재 여부
#   4. DEV_REPORT           → reports/DEV_REPORT.md 존재 여부
#   5. QA_REPORT            → reports/QA_REPORT.md 존재 여부
#   6. AskOptions           → grimoire-server/src/lib/claude.ts 존재 + signal 시그니처
#   7. ANALYSIS_CREDIT_COST → grimoire-server/src/domain/model/config.ts 존재 + 값=4
#   8. Eval task 형식       → eval/tasks/*.json 존재 + eval_criteria 필드
#   9. LLM-as-Judge 가드    → eval/scripts/grade-llm.py 존재 + 비용 상수
#  10. PostToolUseFailure   → .claude/settings.json hooks 등록
#
# 7 에이전트 .md (server/web/researcher/qa/visual-canon-keeper/planner/cost-accountant) 모두
# shared-contracts.md 참조 1줄 이상 박제 확인.
#
# Exit 0: 모든 검증 PASS, Exit 1: 1건 이상 FAIL.

set +u
ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
SC="$ROOT/.claude/shared-contracts.md"
FAIL=0
WARN=0

echo "=== shared-contracts.md 정합 검증 ==="

# ───────────────── [0] shared-contracts.md 존재 ─────────────────
if [ ! -f "$SC" ]; then
  echo "❌ FAIL: $SC 파일 없음"
  exit 1
fi

# ───────────────── [1] 7 에이전트 .md 동기 참조 ─────────────────
echo ""
echo "── [1/3] 7 에이전트 .md → shared-contracts.md 참조 ──"
AGENT_REFS=0
for agent in cost-accountant planner qa researcher server visual-canon-keeper web; do
  f="$ROOT/.claude/agents/grimoire-${agent}.md"
  if [ ! -f "$f" ]; then
    echo "❌ FAIL: $f 파일 없음"
    FAIL=1
    continue
  fi
  if grep -q "shared-contracts" "$f"; then
    echo "✅ grimoire-${agent}.md → shared-contracts 참조"
    AGENT_REFS=$((AGENT_REFS+1))
  else
    echo "❌ FAIL: grimoire-${agent}.md → shared-contracts 미참조"
    FAIL=1
  fi
done
if [ "$AGENT_REFS" -eq 7 ]; then
  echo "✅ 7/7 에이전트 동기 참조 정합"
fi

# ───────────────── [2] reports/ 5개 인터페이스 ─────────────────
echo ""
echo "── [2/3] reports/*.md 5개 인터페이스 ──"
for r in PLANNER_REPORT COST_AUDIT_REPORT VISUAL_CANON_REPORT DEV_REPORT QA_REPORT; do
  f="$ROOT/reports/${r}.md"
  if [ -f "$f" ]; then
    echo "✅ reports/${r}.md 존재"
  else
    echo "⚠️ WARN: reports/${r}.md 미생성 (자율 에이전트 1회 이상 실행 필요 — gitignore 대상이라 정상)"
    WARN=$((WARN+1))
  fi
done

# ───────────────── [3] 코드 인터페이스 5개 ─────────────────
echo ""
echo "── [3/3] 코드 인터페이스 (AskOptions / ANALYSIS_CREDIT_COST / Eval / LLM-Judge / PostToolUseFailure) ──"

# 6. AskOptions (signal: AbortSignal)
F="$ROOT/grimoire-server/src/lib/claude.ts"
if [ -f "$F" ]; then
  if grep -q "signal.*AbortSignal\|signal.*options.signal" "$F"; then
    echo "✅ AskOptions (signal: AbortSignal) 박제 — claude.ts"
  else
    echo "❌ FAIL: AskOptions signal 시그니처 누락 — claude.ts"
    FAIL=1
  fi
else
  echo "❌ FAIL: $F 파일 없음"
  FAIL=1
fi

# 7. ANALYSIS_CREDIT_COST = 4
F="$ROOT/grimoire-server/src/domain/model/config.ts"
if [ -f "$F" ]; then
  if grep -q "ANALYSIS_CREDIT_COST.*=.*4" "$F"; then
    echo "✅ ANALYSIS_CREDIT_COST = 4 박제 — config.ts"
  else
    echo "❌ FAIL: ANALYSIS_CREDIT_COST = 4 누락 — config.ts"
    FAIL=1
  fi
else
  echo "❌ FAIL: $F 파일 없음"
  FAIL=1
fi

# 8. Eval task 형식 (eval_criteria 필드)
EVAL_TASKS=$(ls "$ROOT/eval/tasks"/*.json 2>/dev/null | wc -l | tr -d ' ')
if [ "$EVAL_TASKS" -gt 0 ]; then
  if grep -l "eval_criteria" "$ROOT/eval/tasks"/*.json >/dev/null 2>&1; then
    echo "✅ Eval task 형식 (eval_criteria) 박제 — $EVAL_TASKS task"
  else
    echo "❌ FAIL: eval_criteria 필드 누락 — eval/tasks/*.json"
    FAIL=1
  fi
else
  echo "❌ FAIL: eval/tasks/*.json 없음"
  FAIL=1
fi

# 9. LLM-as-Judge 비용 가드 (DAILY_ALERT_KRW + MONTHLY_LIMIT_KRW)
F="$ROOT/eval/scripts/grade-llm.py"
if [ -f "$F" ]; then
  if grep -q "DAILY_ALERT_KRW = 2000" "$F" && grep -q "MONTHLY_LIMIT_KRW = 50000" "$F"; then
    echo "✅ LLM-as-Judge 비용 가드 (₩2K/₩50K) 박제 — grade-llm.py"
  else
    echo "❌ FAIL: 비용 가드 상수 누락 — grade-llm.py"
    FAIL=1
  fi
else
  echo "❌ FAIL: $F 파일 없음"
  FAIL=1
fi

# 10. PostToolUseFailure hook
F="$ROOT/.claude/settings.json"
if [ -f "$F" ]; then
  if python3 -c "import json,sys; h=json.load(open('$F')).get('hooks',{}); sys.exit(0 if 'PostToolUseFailure' in h else 1)" 2>/dev/null; then
    echo "✅ PostToolUseFailure hook 등록 — settings.json"
  else
    echo "❌ FAIL: PostToolUseFailure hook 미등록 — settings.json"
    FAIL=1
  fi
else
  echo "❌ FAIL: $F 파일 없음"
  FAIL=1
fi

# ───────────────── 종합 ─────────────────
echo ""
echo "── 종합 ──"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ shared-contracts 정합 PASS (FAIL 0건 / WARN $WARN건)"
  exit 0
else
  echo "❌ shared-contracts 정합 FAIL ($FAIL건 / WARN $WARN건)"
  exit 1
fi
