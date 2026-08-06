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
# ── 면제 카테고리 (2026-05-01 #10_2 NEW-3 명시 박제) ──
# 60-line 황금률은 instruction(명령) 문서에만 적용. 다음은 명시 면제:
#   - research/         : 학습 박제·리서치 노트 (long-form, Claude는 필요 시 부분 Read)
#   - reports/          : 에이전트 산출물 (auto-generated, 형식 정본은 shared-contracts.md)
#   - eval/results/     : eval 실행 결과 누적 (csv + jsonl, 시계열 데이터)
#   - PLANNING_GRIMOIRE.md : 최상위 정본·기획 문서 (사용자 승인 필요, 길이 제한 부적합)
#   - DOC_MAP.html      : 시각 보조 (HTML, 줄수 의미 없음)
#   - HANDOVER_NEXT_SESSION.md : 세션 인계 — 일회성 박제용
# 위 면제 카테고리는 본 sensor의 검사 대상에 포함하지 않으며, 향후 누가 "왜 research/는
# 1300줄인데 PASS인가?"라고 질의해도 본 코멘트가 정본 답변이다.
#
# Exit 0: 모든 파일 PASS, Exit 1: WARN 1건 이상, Exit 2: FAIL 1건 이상.

set +u
ROOT="/Users/sokol/Git/ProjectGrimoire"
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

# ── 에이전트 .md (동적 카운트/순회 — 2026-05-30 F-3: 7 하드코딩 제거) ──
echo ""
AGENT_COUNT=$(ls -1 "$ROOT"/.claude/agents/grimoire-*.md 2>/dev/null | wc -l | tr -d ' ')
echo "── [2/2] ${AGENT_COUNT} 에이전트 .md (각 ≤ 300줄) ──"
for agent_file in "$ROOT"/.claude/agents/grimoire-*.md; do
  [ -f "$agent_file" ] || continue
  check_file "$agent_file" 300 "$(basename "$agent_file")"
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
  RESULT_TAG="FAIL"
  RC=2
elif [ "$WARN" -gt 0 ]; then
  echo ""
  echo "⚠️ WARN 파일 (분할 권장 — instruction degradation 위험):"
  for f in "${WARN_FILES[@]}"; do
    echo "  - $f"
  done
  RESULT_TAG="WARN"
  RC=1
else
  echo "✅ 모든 instruction 파일이 임계값 이하 (책 Ch 08 정합)"
  echo ""
  echo "(면제 카테고리: research/ · reports/ · eval/results/ · PLANNING_GRIMOIRE.md · DOC_MAP.html · HANDOVER_*.md — 본 sensor 검사 대상 아님)"
  RESULT_TAG="PASS"
  RC=0
fi

# sensor-log 박제 (2026-05-02 H8)
bash "$(dirname "$0")/sensor-log.sh" "sensor-instruction-degradation" "$RESULT_TAG" "PASS=$PASS WARN=$WARN FAIL=$FAIL" 2>/dev/null || true
exit $RC
