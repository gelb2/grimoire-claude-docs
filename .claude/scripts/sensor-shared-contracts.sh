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

# ───────────────── [2] reports/ 5개 인터페이스 + 골격 정합 (K3 추가) ─────────────────
# K3 정책 (2026-05-02 묶음 J):
#   - AUTO-GENERATED 헤더 있는 보고서: shared-contracts.md 골격과 정확히 일치 강제 (FAIL)
#   - 헤더 없는 기존 수동 보고서: 존재만 검증 (legacy 면제 — 마이그레이션은 별개 작업)
#   - generate-report-template.sh --apply로 새로 생성하면 자동 골격 박제됨

echo ""
echo "── [2/3] reports/*.md 5개 인터페이스 + 골격 정합 (K3, AUTO-GENERATED만 강제) ──"

declare -a REPORT_REQS=(
  "SWEEP_REPORT|## 0. 메타|## 1. 경쟁사 변동|## 2. AI 모델 가격|## 4. HANDOFF"
  "PLANNER_REPORT|## 0. 메타|## 1. 오늘 위임|## 2. HANDOFF"
  "COST_AUDIT_REPORT|## 0. 종합 판정|## 1. 안전배수 표|## 3. HANDOFF"
  "VISUAL_CANON_REPORT|## 0. 종합 판정|## 1. 사슴악마 정본 대조 결과|## 3. HANDOFF"
  "DEV_REPORT|## Server 섹션|## Web 섹션"
  "QA_REPORT|## 0. 배포 게이트 판정|## 1. dev/qa 센서 대조|## 5. HANDOFF to 사용자"
)

for entry in "${REPORT_REQS[@]}"; do
  IFS='|' read -ra parts <<< "$entry"
  rname="${parts[0]}"
  f="$ROOT/reports/${rname}.md"
  if [ ! -f "$f" ]; then
    echo "⚠️ WARN: reports/${rname}.md 미생성 (gitignore — generate-report-template.sh --apply 권장)"
    WARN=$((WARN+1))
    continue
  fi
  # AUTO-GENERATED 헤더 유무 분기
  if grep -q "AUTO-GENERATED from .claude/shared-contracts.md" "$f"; then
    # 강제 골격 검증
    missing=0
    for ((i=1; i<${#parts[@]}; i++)); do
      if ! grep -qF "${parts[$i]}" "$f"; then missing=$((missing+1)); fi
    done
    if [ "$missing" -eq 0 ]; then
      echo "✅ reports/${rname}.md AUTO-GENERATED 골격 정합 ($((${#parts[@]}-1))/$((${#parts[@]}-1)) 섹션)"
    else
      echo "❌ FAIL: reports/${rname}.md AUTO-GENERATED인데 $missing 섹션 누락 — generate-report-template 재실행 필요"
      FAIL=1
    fi
  else
    echo "✅ reports/${rname}.md 존재 (legacy 수동 작성 — 골격 검증 면제)"
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
  if [ "$WARN" -gt 0 ]; then RESULT_TAG="WARN"; else RESULT_TAG="PASS"; fi
  RC=0
else
  echo "❌ shared-contracts 정합 FAIL ($FAIL건 / WARN $WARN건)"
  RESULT_TAG="FAIL"; RC=1
fi

# sensor-log 박제 (2026-05-02 H8)
bash "$(dirname "$0")/sensor-log.sh" "sensor-shared-contracts" "$RESULT_TAG" "FAIL=$FAIL WARN=$WARN" 2>/dev/null || true
exit $RC
