#!/bin/bash
# sensor-knowledge-drift.sh — .claude/knowledge/*.md ↔ HARNESS §14.5 + 참조처 정합 검증
#
# 책 Ch 16 shared contracts 패턴 적용.
# knowledge 파일이 추가/이동/삭제되어도 .claude/knowledge/README.md 인덱스 + 참조처 갱신 안 하면 drift 발생.
#
# 검증 항목:
#   1. .claude/knowledge/*.md 실측 (README 제외)
#   2. .claude/knowledge/README.md에 모든 knowledge 파일 박제 (인덱스 정합)
#   3. AUTOMATION.md §5 (또는 동등) knowledge 카운트 정합
#   4. 각 knowledge 파일 → 다른 곳에서 참조 ≥1 (orphan 방지)
#
# Exit 0 PASS / 1 WARN / 2 FAIL

set +u
ROOT="/Users/sokol/Git/ProjectGrimoire"
KDIR="$ROOT/.claude/knowledge"
README="$KDIR/README.md"
FAIL=0
WARN=0

echo "=== sensor-knowledge-drift (책 Ch 16 + Ouroboros knowledge graph) ==="
echo ""

# [1] 실측 카운트
ACTUAL_FILES=$(ls "$KDIR"/*.md 2>/dev/null | grep -v README | sort)
ACTUAL_COUNT=$(echo "$ACTUAL_FILES" | grep -cv "^$")
echo "── [1/4] 실측 — $ACTUAL_COUNT knowledge 파일 (README 제외) ──"

# [2] README 인덱스 정합
echo ""
echo "── [2/4] README.md 인덱스 정합 ──"
if [ ! -f "$README" ]; then
  echo "  ❌ FAIL: $README 없음"
  FAIL=1
else
  for f in $ACTUAL_FILES; do
    name=$(basename "$f")
    if grep -q "$name" "$README"; then
      echo "  ✅ $name → README 박제"
    else
      echo "  ⚠️ WARN: $name → README 미박제 (인덱스 누락)"
      WARN=$((WARN+1))
    fi
  done
fi

# [3] AUTOMATION.md knowledge 카운트
echo ""
echo "── [3/4] AUTOMATION.md knowledge 카운트 정합 ──"
AUTO_DOC=$(grep -E "^## 5\. knowledge.*\([0-9]+개" "$ROOT/AUTOMATION.md" | sed -E 's/.*\(([0-9]+)개.*/\1/')
if [ -n "$AUTO_DOC" ]; then
  if [ "$AUTO_DOC" = "$ACTUAL_COUNT" ]; then
    echo "  ✅ AUTOMATION §5 = $AUTO_DOC == 실측 $ACTUAL_COUNT"
  else
    echo "  ⚠️ WARN: AUTOMATION §5 = $AUTO_DOC != 실측 $ACTUAL_COUNT (drift)"
    WARN=$((WARN+1))
  fi
else
  echo "  ℹ️ AUTOMATION §5 카운트 표기 없음 (자유 형식 — 검사 면제)"
fi

# [4] orphan knowledge 식별
echo ""
echo "── [4/4] orphan knowledge 식별 (다른 곳 참조 0건) ──"
ORPHAN_COUNT=0
for f in $ACTUAL_FILES; do
  name=$(basename "$f")
  # 자기 자신 + README + 본 sensor 제외하고 참조 카운트
  refs=$(grep -r -l "$name" "$ROOT" --include="*.md" --include="*.sh" --include="*.json" --include="*.html" 2>/dev/null | grep -v "knowledge/$name" | grep -v "knowledge/README.md" | grep -v "scripts/sensor-knowledge-drift.sh" | wc -l | tr -d ' ')
  if [ "$refs" -eq 0 ]; then
    echo "  💡 orphan: $name (다른 정본/sensor/skill에서 참조 0건)"
    ORPHAN_COUNT=$((ORPHAN_COUNT+1))
  else
    echo "  ✅ $name → $refs 곳 참조"
  fi
done
if [ "$ORPHAN_COUNT" -gt 0 ]; then
  WARN=$((WARN+ORPHAN_COUNT))
fi

# 종합
echo ""
echo "── 종합 ──"
echo "PASS knowledge: $ACTUAL_COUNT / WARN: $WARN / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  RESULT_TAG="FAIL"; RC=2
elif [ "$WARN" -gt 0 ]; then
  RESULT_TAG="WARN"; RC=1
  echo "⚠️ WARN — README 인덱스 갱신 또는 참조 추가 권장"
else
  RESULT_TAG="PASS"; RC=0
  echo "✅ knowledge 정합 — drift 0건"
fi

# sensor-log 박제 (H8 패턴)
bash "$(dirname "$0")/sensor-log.sh" "sensor-knowledge-drift" "$RESULT_TAG" "knowledge=$ACTUAL_COUNT WARN=$WARN FAIL=$FAIL orphan=$ORPHAN_COUNT" 2>/dev/null || true
exit $RC
