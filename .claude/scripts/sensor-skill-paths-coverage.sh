#!/bin/bash
# sensor-skill-paths-coverage.sh — Skills frontmatter 일관성 검증
#
# 동기 (HARNESS §6.4 + 묶음 D J4):
#   Anthropic 공식 Skill frontmatter 필드:
#     - triggers: UserPromptSubmit 자동 발동 키워드
#     - paths: 적용 파일 glob
#     - disable-model-invocation: 사용자 명시 호출만 (true/false)
#     - effort: low/medium/high
#     - model: opus/sonnet/haiku
#
#   ProjectGrimoire 정합 규칙:
#     1. (triggers 또는 disable-model-invocation:true) 둘 중 하나는 있어야 호출 가능 (FAIL 임계)
#     2. paths 미박제 시 trigger-mode 메타 1줄 박제 (J4 패턴 — 의도적 skip 명시) (WARN 권장)
#     3. effort 박제 (HARNESS §6.4 1차 마이그레이션, 2026-04-27)
#
# Exit 0 PASS / 1 WARN / 2 FAIL

set +u
ROOT="/Users/sokol/Git/ProjectGrimoire"
SKILLS_DIR="$ROOT/.claude/skills"
PASS=0
WARN=0
FAIL=0
WARN_LIST=()
FAIL_LIST=()

echo "=== sensor-skill-paths-coverage (Skills frontmatter 일관성) ==="
echo ""

for skill_dir in "$SKILLS_DIR"/*/; do
  name=$(basename "$skill_dir")
  f="$skill_dir/SKILL.md"
  if [ ! -f "$f" ]; then
    echo "  ❌ FAIL $name: SKILL.md 없음"
    FAIL=$((FAIL+1))
    FAIL_LIST+=("$name (SKILL.md 누락)")
    continue
  fi

  has_triggers=$(grep -c "^triggers:" "$f" 2>/dev/null)
  has_disable=$(grep -c "^disable-model-invocation: *true" "$f" 2>/dev/null)
  has_paths=$(grep -c "^paths:" "$f" 2>/dev/null)
  has_trigger_mode=$(grep -c "trigger-mode:" "$f" 2>/dev/null)
  has_effort=$(grep -c "^effort:" "$f" 2>/dev/null)

  status="PASS"
  reason=""

  # [1] FAIL 임계: 호출 정의 누락
  if [ "$has_triggers" -eq 0 ] && [ "$has_disable" -eq 0 ]; then
    status="FAIL"
    reason="호출 정의 누락 (triggers 또는 disable-model-invocation:true 필요)"
    FAIL=$((FAIL+1))
    FAIL_LIST+=("$name ($reason)")
  fi

  # [2] WARN 임계: paths 미박제 + trigger-mode 메타 미박제
  if [ "$status" = "PASS" ]; then
    if [ "$has_paths" -eq 0 ] && [ "$has_trigger_mode" -eq 0 ]; then
      status="WARN"
      reason="paths 미박제 + trigger-mode 메타 누락 (J4 패턴 권장)"
      WARN=$((WARN+1))
      WARN_LIST+=("$name")
    fi
  fi

  # [3] WARN 임계: effort 누락
  if [ "$status" = "PASS" ] && [ "$has_effort" -eq 0 ]; then
    status="WARN"
    reason="effort 필드 누락 (HARNESS §6.4 1차 마이그 권장)"
    WARN=$((WARN+1))
    WARN_LIST+=("$name (effort 누락)")
  fi

  if [ "$status" = "PASS" ]; then
    PASS=$((PASS+1))
    printf "  ✅ %-32s  triggers=%s paths=%s disable=%s trigger-mode=%s effort=%s\n" "$name" "$has_triggers" "$has_paths" "$has_disable" "$has_trigger_mode" "$has_effort"
  else
    printf "  %s %-32s  %s\n" "$([ "$status" = "FAIL" ] && echo "❌" || echo "⚠️")" "$name" "$reason"
  fi
done

# 종합
TOTAL=$((PASS + WARN + FAIL))
echo ""
echo "── 종합 ──"
echo "PASS: $PASS / WARN: $WARN / FAIL: $FAIL (총 $TOTAL skill)"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ FAIL skill (즉시 수정 필요):"
  for s in "${FAIL_LIST[@]}"; do echo "  - $s"; done
  RESULT_TAG="FAIL"; RC=2
elif [ "$WARN" -gt 0 ]; then
  echo ""
  echo "⚠️ WARN skill (J4 패턴 박제 권장):"
  for s in "${WARN_LIST[@]}"; do echo "  - $s"; done
  RESULT_TAG="WARN"; RC=1
else
  echo "✅ 모든 skill frontmatter 정합"
  RESULT_TAG="PASS"; RC=0
fi

# sensor-log 박제 (H8 패턴)
bash "$(dirname "$0")/sensor-log.sh" "sensor-skill-paths-coverage" "$RESULT_TAG" "PASS=$PASS WARN=$WARN FAIL=$FAIL total=$TOTAL" 2>/dev/null || true
exit $RC
