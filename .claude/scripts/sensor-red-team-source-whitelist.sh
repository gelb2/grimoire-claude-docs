#!/usr/bin/env bash
# sensor-red-team-source-whitelist.sh — 자율학습 출처 whitelist 강제 (책 Ch 17 Layer 1 보안)
#
# 자율학습 데이터 수집 시 사용 가능한 출처만 허용 (prompt injection 방어).
# 검증되지 않은 출처는 차단 — 책 Ch 17 보안 Layer 1 + Ch 23 안티패턴 #5 하네스 부패 방어.
#
# 사용:
#   sensor-red-team-source-whitelist.sh <URL>
#
# Whitelist (책 V1.1 + 산업 정본):
#   - docs.anthropic.com (Anthropic 공식)
#   - github.com/obra/superpowers (MIT, ProjectGrimoire 차용 원본)
#   - github.com/Q00/ouroboros (소크라테스 정본)
#   - github.com/ng/adversarial-review (Optimizer/Skeptic 정본)
#   - github.com/zscole/adversarial-spec (debate-to-consensus 정본 — 참조만, LLM 호출 X)
#   - arxiv.org (검증된 hash, AI safety 논문)
#   - owasp.org (LLM Top 10 / 보안 표준)
#   - developer.mozilla.org (Mozilla MDN — 보안/표준)
#   - princeton-nlp.github.io (Socratic AI 정본)
#
# Exit:
#   0 — URL이 whitelist 정합 (자율학습 데이터 수집 가능)
#   1 — URL이 whitelist 외 (차단 — 사용자 승인 게이트)
#   2 — 인자 누락

set +u

URL="${1:?사용: sensor-red-team-source-whitelist.sh <URL>}"

WHITELIST=(
  "https://docs.anthropic.com"
  "https://www.anthropic.com"
  "https://github.com/obra/superpowers"
  "https://github.com/Q00/ouroboros"
  "https://github.com/ng/adversarial-review"
  "https://github.com/zscole/adversarial-spec"
  "https://github.com/confident-ai/deepteam"
  "https://github.com/promptfoo/promptfoo"
  "https://arxiv.org"
  "https://owasp.org"
  "https://developer.mozilla.org"
  "https://princeton-nlp.github.io"
  "https://www.trydeepteam.com"
  "https://www.promptfoo.dev"
  "https://mbrenndoerfer.com"
  "https://aquilax.ai"
  "https://devsecopsschool.com"
)

for prefix in "${WHITELIST[@]}"; do
  if [[ "$URL" == "$prefix"* ]]; then
    echo "✅ PASS whitelist 정합: $URL"
    bash "$(dirname "$0")/sensor-log.sh" "sensor-red-team-source-whitelist" "PASS" "url=$URL" 2>/dev/null || true
    exit 0
  fi
done

echo "❌ FAIL whitelist 외 출처: $URL"
echo ""
echo "허용 출처 (책 V1.1 + 산업 정본):"
for prefix in "${WHITELIST[@]}"; do
  echo "  - $prefix"
done
echo ""
echo "💡 사용자 승인 필요 — 새 whitelist 출처 추가 시 사용자 명시 결정 후 본 sensor 갱신"

bash "$(dirname "$0")/sensor-log.sh" "sensor-red-team-source-whitelist" "FAIL" "url=$URL (whitelist 외)" 2>/dev/null || true
exit 1
