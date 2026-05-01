#!/bin/bash
# sensor-agent-interaction.sh — agent-interaction-matrix.md 형식 정합 자동 검증
#
# 책 Ch 16 shared-contracts 패턴 + agent-system.md 호출 매트릭스 박제 강제.
#
# 검증:
#   1. agent-interaction-matrix.md 8행 박제 (사용자 + 7 에이전트 = FROM 행)
#   2. self 셀 7건 박제 (대각선 — 자기 자신 호출 무의미)
#   3. ✅ 또는 ❌ 또는 (간접) 키워드 충분히 박제 (49 cells 중 ≥30건)
#   4. shared-contracts 참조 박제 (Ch 16 정합)
#
# 미적용 (P1 후속):
#   - 7 에이전트 .md → matrix 참조 박제 (현재 0건)
#   - jsonl 파싱 → 실제 호출 vs matrix 비교 (복잡, 별도 sensor)
#
# Exit 0 PASS / 1 WARN / 2 FAIL

set +u
ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
MATRIX="$ROOT/.claude/knowledge/agent-interaction-matrix.md"
FAIL=0
WARN=0

echo "=== sensor-agent-interaction (agent-interaction-matrix 정합) ==="

if [ ! -f "$MATRIX" ]; then
  echo "FAIL: $MATRIX 파일 없음"
  exit 2
fi

# [1] FROM 행 박제 (사용자 + 7 에이전트 = 8행)
ROWS=$(grep -c "^| \*\*" "$MATRIX")
echo ""
echo "── [1/4] FROM 행 박제 (8 = 사용자 + 7 에이전트) ──"
if [ "$ROWS" -eq 8 ]; then
  echo "PASS FROM 행: ${ROWS}건"
elif [ "$ROWS" -ge 7 ]; then
  echo "WARN FROM 행: ${ROWS}건 (8 권장)"
  WARN=$((WARN+1))
else
  echo "FAIL FROM 행: ${ROWS}건 < 7"
  FAIL=$((FAIL+1))
fi

# [2] self 셀 (대각선) — 7 에이전트 자기 자신 호출 = self 박제
SELF=$(grep -c "self" "$MATRIX")
echo ""
echo "── [2/4] self 셀 박제 (대각선 7건) ──"
if [ "$SELF" -ge 7 ]; then
  echo "PASS self 셀: ${SELF}건"
else
  echo "FAIL self 셀: ${SELF}건 < 7"
  FAIL=$((FAIL+1))
fi

# [3] 핸드오프 키워드 박제 (49 cells 중 30건 이상)
HANDOFF=$(grep -oE "✅|❌|\(간접\)" "$MATRIX" | wc -l | tr -d ' ')
echo ""
echo "── [3/4] 핸드오프 키워드 박제 (≥30건) ──"
if [ "$HANDOFF" -ge 30 ]; then
  echo "PASS 핸드오프 키워드: ${HANDOFF}건"
else
  echo "WARN 핸드오프 키워드: ${HANDOFF}건 (30+ 권장)"
  WARN=$((WARN+1))
fi

# [4] shared-contracts 참조 (책 Ch 16 정합)
SC_REF=$(grep -c "shared-contracts" "$MATRIX")
echo ""
echo "── [4/4] shared-contracts 참조 (Ch 16 정합) ──"
if [ "$SC_REF" -ge 1 ]; then
  echo "PASS shared-contracts 참조: ${SC_REF}건"
else
  echo "FAIL shared-contracts 참조: 0건 (Ch 16 도입 누락)"
  FAIL=$((FAIL+1))
fi

# 종합
echo ""
echo "── 종합 ──"
if [ "$FAIL" -gt 0 ]; then
  echo "FAIL agent-interaction-matrix 정합 ($FAIL건 / WARN $WARN건)"
  exit 2
elif [ "$WARN" -gt 0 ]; then
  echo "WARN agent-interaction-matrix 정합 ($WARN건)"
  exit 1
else
  echo "PASS agent-interaction-matrix 정합"
  exit 0
fi
