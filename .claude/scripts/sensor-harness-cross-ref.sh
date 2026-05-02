#!/usr/bin/env bash
# sensor-harness-cross-ref.sh — research/HARNESS_*.md 분리 정본 cross-reference drift 검증 (NEW-C)
#
# 동기 (#10_4 묶음 L에서 §13/§15/§17 분리 → 8개 파일 cross-ref 위험):
#   - HARNESS_ENGINEERING.md (메인) ↔ HARNESS_BIBLIOGRAPHY.md (§13)
#   - HARNESS_ENGINEERING.md ↔ HARNESS_FIELD_PATTERNS_4.md (§15.7 위임 매트릭스)
#   - HARNESS_ENGINEERING.md ↔ HARNESS_SPLIT_AND_EDD.md (§17 분할 + EDD)
#   - HARNESS_ENGINEERING.md ↔ HARNESS_ROOT_WORKSPACE.md (§11 루트 git)
#
# 검증:
#   1. 메인이 분리 정본 4개 모두 pointer로 가리키는가
#   2. 분리 정본이 메인 §N 박제 (출처 인용)하는가
#   3. 분리 정본 줄수 임계 (sensor-instruction-degradation 면제 카테고리지만 모니터)
#
# Exit 0 PASS / 1 WARN / 2 FAIL

set +u

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
MAIN="$ROOT/research/HARNESS_ENGINEERING.md"
SPLITS=(
  "research/HARNESS_BIBLIOGRAPHY.md"
  "research/HARNESS_FIELD_PATTERNS_4.md"
  "research/HARNESS_SPLIT_AND_EDD.md"
  "research/HARNESS_ROOT_WORKSPACE.md"
  "research/HARNESS_ADVERSARIAL_VERIFICATION.md"
)

FAIL=0
WARN=0

echo "=== sensor-harness-cross-ref (#10_4 묶음 L 분리 정본 정합) ==="
echo ""

if [ ! -f "$MAIN" ]; then
  echo "❌ FAIL: HARNESS_ENGINEERING.md 없음"
  exit 2
fi

# [1] 메인이 분리 정본 4개 모두 pointer 박제
echo "── [1/3] 메인 → 분리 4파일 pointer 박제 ──"
for split in "${SPLITS[@]}"; do
  fname=$(basename "$split")
  if grep -q "$fname" "$MAIN"; then
    echo "  ✅ $fname pointer 박제"
  else
    echo "  ❌ FAIL $fname pointer 누락"
    FAIL=$((FAIL+1))
  fi
done

# [2] 분리 정본이 출처 인용 (HARNESS_ENGINEERING 또는 분리 사유 박제)
echo ""
echo "── [2/3] 분리 정본 → 출처 인용 ──"
for split in "${SPLITS[@]}"; do
  fpath="$ROOT/$split"
  fname=$(basename "$split")
  if [ ! -f "$fpath" ]; then
    echo "  ❌ FAIL $fname 파일 없음"
    FAIL=$((FAIL+1))
    continue
  fi
  if grep -q "HARNESS_ENGINEERING\|분리\|2026-05-02 묶음 L\|M1\|M2\|M3\|NEW-12" "$fpath"; then
    echo "  ✅ $fname 출처/분리사유 박제"
  else
    echo "  ⚠️ WARN $fname 출처 박제 약함"
    WARN=$((WARN+1))
  fi
done

# [3] 분리 정본 줄수 (instruction-degradation 면제이나 monitor)
echo ""
echo "── [3/3] 분리 정본 줄수 모니터 (long-form 면제, 단 균형) ──"
for split in "${SPLITS[@]}"; do
  fpath="$ROOT/$split"
  fname=$(basename "$split")
  if [ -f "$fpath" ]; then
    L=$(wc -l < "$fpath" | tr -d ' ')
    if [ "$L" -gt 1000 ]; then
      echo "  ⚠️ WARN $fname ${L}줄 > 1000 (재분할 검토 후보)"
      WARN=$((WARN+1))
    else
      echo "  ✅ $fname ${L}줄"
    fi
  fi
done

# 종합
echo ""
echo "── 종합 ──"
if [ "$FAIL" -gt 0 ]; then
  echo "❌ harness cross-ref FAIL ($FAIL건 / WARN $WARN건)"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-harness-cross-ref" "FAIL" "FAIL=$FAIL WARN=$WARN" 2>/dev/null || true
  exit 2
elif [ "$WARN" -gt 0 ]; then
  echo "⚠️ harness cross-ref WARN ($WARN건)"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-harness-cross-ref" "WARN" "WARN=$WARN" 2>/dev/null || true
  exit 1
else
  echo "✅ harness cross-ref PASS (#10_4 묶음 L 분리 정합)"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-harness-cross-ref" "PASS" "all-good" 2>/dev/null || true
  exit 0
fi
