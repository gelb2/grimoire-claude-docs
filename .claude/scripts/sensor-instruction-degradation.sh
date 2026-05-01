#!/bin/bash
# sensor-instruction-degradation.sh — instruction 파일 줄수 감시 (HumanLayer 발견)
#
# 책 Ch 08 "60-line 황금률" 적용 검증.
# HumanLayer 발견:
#   - 50개 룰 → 절반 무시
#   - 100개 룰 → 우선순위 상실
# 단일 instruction 파일이 임계값 초과 시 instruction degradation 시작.
#
# ProjectGrimoire 임계값 (분할 정본 기준):
#   CLAUDE.md (root)         ≤ 80줄  (60-line 권장 + 20줄 여유, 현재 73)
#   .claude/AGENTS.md         ≤ 200줄 (현재 114)
#   docs/AGENTS.md            ≤ 300줄 (현재 195)
#   .githooks/AGENTS.md       ≤ 200줄 (현재 125)
#   각 .claude/agents/grimoire-*.md ≤ 300줄 (에이전트 프롬프트 자체)
#
# 임계값 초과 시 WARN (분할 권장).
# 임계값 1.5× 초과 시 FAIL (즉시 분할 필요 — 책 Ch 08 violations).
#
# Exit 0: 모든 파일 PASS, Exit 1: WARN 1건 이상, Exit 2: FAIL 1건 이상.

set +u
ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
PASS=0
WARN=0
FAIL=0
FAIL_FILES=()
WARN_FILES=()

check_file() {
  local file="$1"
  local threshold="$2"
  local label="$3"

  if [ ! -f "$file" ]; then
    echo "  ⚠️ $label 파일 없음: $file (스킵)"
    return
  fi

  local lines=$(wc -l < "$file" | tr -d ' ')
  local fail_threshold=$((threshold * 3 / 2))  # 1.5×

  if [ "$lines" -gt "$fail_threshold" ]; then
    echo "  ❌ FAIL $label: $lines줄 > $fail_threshold (1.5× 임계 — 즉시 분할 필요)"
    FAIL=$((FAIL+1))
    FAIL_FILES+=("$file ($lines줄)")
  elif [ "$lines" -gt "$threshold" ]; then
    echo "  ⚠️ WARN $label: $lines줄 > $threshold (분할 권장 — 책 Ch 08)"
    WARN=$((WARN+1))
    WARN_FILES+=("$file ($lines줄)")
  else
    echo "  ✅ PASS $label: $lines줄 ≤ $threshold"
    PASS=$((PASS+1))
  fi
}

echo "=== sensor-instruction-degradation (책 Ch 08 60-line 황금률) ==="
echo ""

# ── 분할 정본 4파일 ──
echo "── [1/2] 분할 정본 4파일 (root + 3 AGENTS.md) ──"
check_file "$ROOT/CLAUDE.md" 80 "CLAUDE.md (root)"
check_file "$ROOT/.claude/AGENTS.md" 200 ".claude/AGENTS.md"
check_file "$ROOT/docs/AGENTS.md" 300 "docs/AGENTS.md"
check_file "$ROOT/.githooks/AGENTS.md" 200 ".githooks/AGENTS.md"

# ── 7 에이전트 .md ──
echo ""
echo "── [2/2] 7 에이전트 .md (각 ≤ 300줄) ──"
for agent in cost-accountant planner qa researcher server visual-canon-keeper web; do
  check_file "$ROOT/.claude/agents/grimoire-${agent}.md" 300 "grimoire-${agent}.md"
done

# ── 종합 ──
echo ""
echo "── 종합 ──"
TOTAL=$((PASS + WARN + FAIL))
echo "PASS: $PASS / WARN: $WARN / FAIL: $FAIL (총 $TOTAL 파일)"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ FAIL 파일 (즉시 분할 필요 — 책 Ch 08 위반):"
  for f in "${FAIL_FILES[@]}"; do
    echo "  - $f"
  done
  exit 2
elif [ "$WARN" -gt 0 ]; then
  echo ""
  echo "⚠️ WARN 파일 (분할 권장 — instruction degradation 위험):"
  for f in "${WARN_FILES[@]}"; do
    echo "  - $f"
  done
  exit 1
else
  echo "✅ 모든 instruction 파일이 임계값 이하 (책 Ch 08 정합)"
  exit 0
fi
