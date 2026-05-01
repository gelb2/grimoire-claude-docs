#!/bin/bash
# sensor-agent-priority-labels.sh — 7 에이전트 .md GMP v2.2 우선순위 라벨링 정합 검증
#
# GMP v2.2 (prompt-engineering/GMP-v2.2.md) 정본 패턴:
#   - [MUST]   = 절대 금지 / 강제 (≥5건/에이전트, 충분한 강제 표명)
#   - [SHOULD] = 권장 (≥1건/에이전트, 권장 사항 명시)
#   - [NICE]   = 선택 (≥0건, strict 안 함)
#
# 7 에이전트 일관 적용 강제. 누락 시 prompt 일관성 약화 → WARN.
#
# Exit 0 PASS / 1 WARN / 2 FAIL

set +u
ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
FAIL=0
WARN=0
WARN_AGENTS=()

echo "=== sensor-agent-priority-labels (GMP v2.2 [MUST]/[SHOULD]/[NICE] 일관성) ==="
echo ""

for agent in cost-accountant planner qa researcher server visual-canon-keeper web; do
  f="$ROOT/.claude/agents/grimoire-${agent}.md"
  if [ ! -f "$f" ]; then
    echo "❌ FAIL grimoire-${agent}.md: 파일 없음"
    FAIL=$((FAIL+1))
    continue
  fi

  must=$(grep -c "\[MUST\]" "$f")
  should=$(grep -c "\[SHOULD\]" "$f")
  nice=$(grep -c "\[NICE\]" "$f")

  status="PASS"
  reason=""

  # MUST 임계 (절대 금지 충분)
  if [ "$must" -lt 5 ]; then
    status="FAIL"
    reason="MUST $must < 5 (절대 금지 부족)"
    FAIL=$((FAIL+1))
  fi

  # SHOULD 임계 (권장 명시)
  if [ "$should" -lt 1 ]; then
    if [ "$status" = "PASS" ]; then
      status="WARN"
      reason="SHOULD $should < 1 (권장 사항 누락)"
      WARN=$((WARN+1))
      WARN_AGENTS+=("grimoire-${agent}.md")
    fi
  fi

  printf "  %s grimoire-%-22s MUST %2d / SHOULD %d / NICE %d   %s\n" "$status" "${agent}.md" "$must" "$should" "$nice" "$reason"
done

# 종합
echo ""
echo "── 종합 ──"
echo "PASS: $((7 - WARN - FAIL)) / WARN: $WARN / FAIL: $FAIL (총 7 에이전트)"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ FAIL 에이전트 (즉시 수정 필요)"
  exit 2
elif [ "$WARN" -gt 0 ]; then
  echo ""
  echo "⚠️ WARN 에이전트 (SHOULD 라벨 보강 권장 — GMP v2.2 정합):"
  for a in "${WARN_AGENTS[@]}"; do
    echo "  - $a"
  done
  exit 1
else
  echo "✅ 모든 에이전트 GMP v2.2 라벨 정합"
  exit 0
fi
