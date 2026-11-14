#!/bin/bash
# update-harness-inventory.sh — 실측 자산 카운트 → HARNESS_ENGINEERING.md §14.X 자동 갱신
#
# 사유 (NEW-4 분석):
#   2026-05-01 sensor-eval-trend WARN의 최근 10회 FAIL 4건 모두 동일 패턴 —
#   새 sensor/skill 추가 후 HARNESS §14.X 카운트 갱신을 잊고 commit하면
#   instructions-drift-check.sh + regression-006이 사후 FAIL을 잡는다.
#
#   본 generator는 사전에 카운트를 자동 갱신하여 drift 자체를 방지한다.
#   책 Ch 16 — 인터페이스 변경 시 즉시 갱신 (drift 0건 유지).
#
# 검사·갱신 대상:
#   §14.2 Skills    (.claude/skills/*/SKILL.md)
#   §14.3 Hooks     (settings.json hooks 이벤트)
#   §14.4 Sensors   (.claude/scripts/sensor-*.sh)
#   §14.5 Knowledge (.claude/knowledge/*.md, README 제외)
#
# 사용법:
#   bash .claude/scripts/update-harness-inventory.sh                # dry-run
#   bash .claude/scripts/update-harness-inventory.sh --apply         # 실제 갱신
#
# Exit 0 정합 / 1 drift 발견 (dry-run) / 2 갱신 실패

set -u

ROOT="/Users/sokol/Git/ProjectGrimoire"
HARNESS="$ROOT/research/HARNESS_ENGINEERING.md"
MODE="dry-run"

for arg in "$@"; do
  case "$arg" in
    --apply) MODE="apply" ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "❌ 알 수 없는 옵션: $arg"; exit 1 ;;
  esac
done

if [ ! -f "$HARNESS" ]; then
  echo "❌ FAIL: $HARNESS 없음"
  exit 2
fi

echo "=== update-harness-inventory (mode=$MODE) ==="
echo "정본: $HARNESS"
echo ""

# 실측 카운트
SKILLS_ACTUAL=$(ls -d "$ROOT"/.claude/skills/*/ 2>/dev/null | grep -v "_archive" | wc -l | tr -d ' ')
SENSORS_ACTUAL=$(ls "$ROOT"/.claude/scripts/sensor-*.sh 2>/dev/null | wc -l | tr -d ' ')
KNOWLEDGE_ACTUAL=$(ls "$ROOT"/.claude/knowledge/*.md 2>/dev/null | grep -v "README" | wc -l | tr -d ' ')

# 현재 문서 카운트 추출
SKILLS_DOC=$(grep -E "^### 14\.2 Skills [0-9]+종" "$HARNESS" | sed -E 's/.*Skills ([0-9]+)종.*/\1/')
SENSORS_DOC=$(grep -E "^### 14\.4 Sensors [0-9]+개" "$HARNESS" | sed -E 's/.*Sensors ([0-9]+)개.*/\1/')

DRIFT=0
declare -a UPDATES=()

check_drift() {
  local label="$1"
  local doc="$2"
  local actual="$3"

  if [ "$doc" = "$actual" ]; then
    printf "  ✅ %-15s 문서=%s == 실측=%s\n" "$label" "$doc" "$actual"
  else
    printf "  ⚠️ %-15s 문서=%s != 실측=%s (drift)\n" "$label" "$doc" "$actual"
    DRIFT=$((DRIFT+1))
    UPDATES+=("$label:$doc:$actual")
  fi
}

check_drift "Skills (§14.2)" "$SKILLS_DOC" "$SKILLS_ACTUAL"
check_drift "Sensors (§14.4)" "$SENSORS_DOC" "$SENSORS_ACTUAL"

# Knowledge §14.5 — 본문 형식이 다양해 카운트 검증만 수행 (자동 갱신 X)
echo "  ℹ️ Knowledge      실측=$KNOWLEDGE_ACTUAL (§14.5 자유 형식, 수동 갱신 권장)"

echo ""
echo "── 종합 ──"

if [ "$DRIFT" -eq 0 ]; then
  echo "✅ 모든 카운트 정합 — drift 0건"
  exit 0
fi

if [ "$MODE" = "dry-run" ]; then
  echo "⚠️ drift $DRIFT건 발견. --apply 추가 시 자동 갱신:"
  for u in "${UPDATES[@]}"; do
    echo "  - $u"
  done
  exit 1
fi

# Apply 모드 — sed로 inplace 갱신 (BSD sed 호환)
echo "🔄 갱신 적용..."
APPLIED=0

for u in "${UPDATES[@]}"; do
  label="${u%%:*}"
  rest="${u#*:}"
  doc="${rest%%:*}"
  actual="${rest#*:}"

  case "$label" in
    "Skills (§14.2)")
      # "### 14.2 Skills 19종" → "### 14.2 Skills 20종"
      sed -i '' -E "s/(^### 14\.2 Skills )[0-9]+(종.*)/\1${actual}\2/" "$HARNESS"
      printf "  ✅ Skills §14.2: %s → %s\n" "$doc" "$actual"
      APPLIED=$((APPLIED+1))
      ;;
    "Sensors (§14.4)")
      # "### 14.4 Sensors 16개" → "### 14.4 Sensors 17개"
      sed -i '' -E "s/(^### 14\.4 Sensors )[0-9]+(개.*)/\1${actual}\2/" "$HARNESS"
      printf "  ✅ Sensors §14.4: %s → %s\n" "$doc" "$actual"
      APPLIED=$((APPLIED+1))
      ;;
  esac
done

echo ""
if [ "${APPLIED:-0}" -eq "${DRIFT:-0}" ]; then
  echo "✅ ${APPLIED:-0}건 갱신 완료. drift sensor + regression-006 검증 권장."
  exit 0
else
  echo "❌ ${APPLIED:-0}/${DRIFT:-0} 갱신만 성공"
  exit 2
fi
