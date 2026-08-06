#!/usr/bin/env bash
# sensor-context-budget.sh — 컨텍스트 토큰 예산 추적 (책 Ch 18 태스크별 토큰 예산)
#
# 동기 (책 Ch 18 4. 태스크별 토큰 예산 + Ch 23 안티패턴 #5 하네스 부패 방어):
#   - "버그 50K / 기능 200K / 리팩토링 500K" 권장 범위 (책 정본)
#   - Claude Code 컨텍스트 = 시스템 프롬프트 + AGENTS.md + 누적 대화
#   - 시스템 프롬프트 + 분할 정본 4파일 = 베이스라인 측정
#   - 베이스라인이 200K 초과 = instruction degradation 임박 (책 Ch 08 60-line 황금률 위반)
#
# 측정 영역:
#   1. CLAUDE.md (root) — 매 세션 자동 로드
#   2. .claude/AGENTS.md — 매 세션 자동 로드
#   3. docs/AGENTS.md — 자식 디렉토리 (매 세션은 아니지만 작업 시작 시)
#   4. .githooks/AGENTS.md — Git 작업 시
#   5. .claude/shared-contracts.md — 에이전트 위임 시
#   6. 7 에이전트 .md (subagent 호출 시)
#
# 토큰 추정 = 줄수 × 평균 30자/줄 × 1 토큰/4자 (한국어 위주, 보수 추정)
#
# 임계값:
#   - 베이스라인 (CLAUDE.md + .claude/AGENTS.md): ≤ 5K 토큰 (PASS) / ≤ 8K (WARN) / >8K (FAIL)
#   - 전체 분할 정본 (4 파일 + shared-contracts): ≤ 10K (PASS) / ≤ 15K (WARN) / >15K (FAIL)
#   - 에이전트 호출 시 추가 (per agent): ≤ 5K (PASS) / >5K (WARN)
#
# Exit 0 PASS / 1 WARN / 2 FAIL

set +u

ROOT="/Users/sokol/Git/ProjectGrimoire"

estimate_tokens() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo 0
    return
  fi
  python3 -c "
import os
size = os.path.getsize('$file')
# 한국어 1 토큰 = 대략 4자 (보수 추정), 영어 1 토큰 = 4자, 마크다운 약간 더 효율
tokens = size // 4
print(tokens)
"
}

echo "=== sensor-context-budget (책 Ch 18 태스크별 토큰 예산) ==="
echo ""

# 베이스라인 (매 세션 자동 로드)
ROOT_TOK=$(estimate_tokens "$ROOT/CLAUDE.md")
ALAGENTS_TOK=$(estimate_tokens "$ROOT/.claude/AGENTS.md")
BASELINE=$((ROOT_TOK + ALAGENTS_TOK))

echo "── 베이스라인 (매 세션 자동) ──"
echo "  CLAUDE.md (root):     ~${ROOT_TOK} tokens"
echo "  .claude/AGENTS.md:    ~${ALAGENTS_TOK} tokens"
echo "  베이스라인 합계:       ~${BASELINE} tokens"

# 전체 분할 정본
DOCS_TOK=$(estimate_tokens "$ROOT/docs/AGENTS.md")
HOOKS_TOK=$(estimate_tokens "$ROOT/.githooks/AGENTS.md")
SC_TOK=$(estimate_tokens "$ROOT/.claude/shared-contracts.md")
FULL_SPLIT=$((BASELINE + DOCS_TOK + HOOKS_TOK + SC_TOK))

echo ""
echo "── 전체 분할 정본 (작업 시작 시) ──"
echo "  + docs/AGENTS.md:       ~${DOCS_TOK} tokens"
echo "  + .githooks/AGENTS.md:  ~${HOOKS_TOK} tokens"
echo "  + .claude/shared-contracts.md: ~${SC_TOK} tokens"
echo "  전체 분할 합계:         ~${FULL_SPLIT} tokens"

# 7 에이전트 .md
echo ""
echo "── 7 에이전트 .md (subagent 호출 시 +) ──"
AGENT_TOTAL=0
WARN_AGENTS=0
for agent in cost-accountant planner qa researcher server visual-canon-keeper web; do
  T=$(estimate_tokens "$ROOT/.claude/agents/grimoire-${agent}.md")
  AGENT_TOTAL=$((AGENT_TOTAL + T))
  STATUS="✅"
  if [ "$T" -gt 5000 ]; then
    STATUS="⚠️"
    WARN_AGENTS=$((WARN_AGENTS+1))
  fi
  printf "  %s grimoire-%-22s ~%d tokens\n" "$STATUS" "${agent}.md" "$T"
done
echo "  7 에이전트 합계:        ~${AGENT_TOTAL} tokens"

# 판정
echo ""
echo "── 판정 (책 Ch 18 임계) ──"
FAIL=0
WARN=0
PASS_FLAG=0

# 베이스라인 판정
if [ "$BASELINE" -gt 8000 ]; then
  echo "  ❌ FAIL 베이스라인: ${BASELINE} > 8K (instruction degradation 임박)"
  FAIL=$((FAIL+1))
elif [ "$BASELINE" -gt 5000 ]; then
  echo "  ⚠️ WARN 베이스라인: ${BASELINE} > 5K (분할 강화 권장)"
  WARN=$((WARN+1))
else
  echo "  ✅ PASS 베이스라인: ${BASELINE} ≤ 5K"
  PASS_FLAG=1
fi

# 전체 분할 판정
if [ "$FULL_SPLIT" -gt 15000 ]; then
  echo "  ❌ FAIL 전체 분할: ${FULL_SPLIT} > 15K"
  FAIL=$((FAIL+1))
elif [ "$FULL_SPLIT" -gt 10000 ]; then
  echo "  ⚠️ WARN 전체 분할: ${FULL_SPLIT} > 10K"
  WARN=$((WARN+1))
else
  echo "  ✅ PASS 전체 분할: ${FULL_SPLIT} ≤ 10K"
fi

# 에이전트 판정
if [ "$WARN_AGENTS" -gt 0 ]; then
  echo "  ⚠️ WARN 에이전트: ${WARN_AGENTS}/7 가 5K 토큰 초과"
  WARN=$((WARN+1))
else
  echo "  ✅ PASS 에이전트: 모두 ≤ 5K"
fi

# 종합
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "❌ context-budget FAIL ($FAIL건 — 책 Ch 18 임계 초과)"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-context-budget" "FAIL" "baseline=$BASELINE full=$FULL_SPLIT" 2>/dev/null || true
  exit 2
elif [ "$WARN" -gt 0 ]; then
  echo "⚠️ context-budget WARN ($WARN건)"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-context-budget" "WARN" "baseline=$BASELINE full=$FULL_SPLIT" 2>/dev/null || true
  exit 1
else
  echo "✅ context-budget PASS (책 Ch 18 정합 — 베이스라인 ${BASELINE} / 전체 ${FULL_SPLIT})"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-context-budget" "PASS" "baseline=$BASELINE full=$FULL_SPLIT" 2>/dev/null || true
  exit 0
fi
