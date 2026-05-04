#!/usr/bin/env bash
# sensor-adversarial-pre-commit.sh — Red Team Constitution 16 principles 적대적 검증
#
# 책 Ch 17 Constitutional AI + Ch 23 자가진단 패턴 차용.
# .claude/knowledge/red-team-constitution.md 16 principles 자동 검증.
# 위반 1건이라도 발견 시 commit 차단.
#
# 발동 조건:
#   - .githooks/pre-commit이 매 commit 직전 자동 호출
#   - 사용자/Claude 명시 호출 가능 (`bash sensor-adversarial-pre-commit.sh`)
#
# Exit:
#   0 — 16 principles 모두 PASS (commit 허용)
#   1 — WARN 1건 이상 (검토 권장, commit 허용)
#   2 — FAIL 1건 이상 (commit 차단 — Constitutional AI 자기-비판 발동 권장)

set +u

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
CONSTITUTION="$ROOT/.claude/knowledge/red-team-constitution.md"
PASS=0
WARN=0
FAIL=0
FAIL_PRINCIPLES=()

check() {
  local pid="$1"
  local title="$2"
  local result="$3"  # PASS/WARN/FAIL
  local detail="$4"
  case "$result" in
    PASS) PASS=$((PASS+1)); printf "  ✅ P%-2d %s — %s\n" "$pid" "$title" "$detail" ;;
    WARN) WARN=$((WARN+1)); printf "  ⚠️  P%-2d %s — WARN: %s\n" "$pid" "$title" "$detail" ;;
    FAIL) FAIL=$((FAIL+1)); FAIL_PRINCIPLES+=("P$pid $title"); printf "  ❌ P%-2d %s — FAIL: %s\n" "$pid" "$title" "$detail" ;;
  esac
}

echo "=== sensor-adversarial-pre-commit (Red Team Constitution 16 Principles) ==="
echo ""

# Constitution 파일 존재 검증
if [ ! -f "$CONSTITUTION" ]; then
  echo "❌ FAIL: red-team-constitution.md 없음 (Phase α-1 미실행)"
  exit 2
fi

# Principle 1 — §0 ZERO-TOLERANCE: commit 메시지에 추정 패턴
echo "── 절대 규정 (Critical) ──"
LAST_COMMIT_MSG=$(git -C "$ROOT" log -1 --format=%B 2>/dev/null || echo "")
if echo "$LAST_COMMIT_MSG" | grep -qE "아마|추정|probably|maybe|기능 정상.*확인 안 함"; then
  check 1 "§0 ZERO-TOLERANCE" "WARN" "최근 commit 메시지에 추정 패턴 의심"
else
  check 1 "§0 ZERO-TOLERANCE" "PASS" "추정 패턴 0건"
fi

# Principle 2 — 사슴악마 시각 정본
if grep -q "사슴악마\|deerdevil" "$ROOT/CLAUDE.md" 2>/dev/null; then
  check 2 "사슴악마 시각 정본" "PASS" "CLAUDE.md 박제 유지"
else
  check 2 "사슴악마 시각 정본" "FAIL" "CLAUDE.md 시각 정본 박제 누락"
fi

# Principle 3 — 작가 콘텐츠 보호
PARSER_VIOLATIONS=$(grep -rE "block\.text\s*=|content\s*=\s*content\.toUpperCase|content\s*=\s*content\.toLowerCase" \
  "$ROOT/grimoire-server/src" --include="*.ts" --exclude="*.spec.ts" 2>/dev/null | wc -l | tr -d ' ')
if [ "$PARSER_VIOLATIONS" -eq 0 ]; then
  check 3 "작가 콘텐츠 보호" "PASS" "본문 수정 패턴 0건"
else
  check 3 "작가 콘텐츠 보호" "FAIL" "$PARSER_VIOLATIONS 건 본문 수정 패턴 검출"
fi

# Principle 4 — §0 원가 철칙
bash "$ROOT/.claude/scripts/sensor-cost-margin.sh" >/dev/null 2>&1
EC=$?
if [ "$EC" -eq 0 ]; then
  check 4 "§0 원가 철칙 (마진 ≥3.5×)" "PASS" "sensor-cost-margin PASS"
elif [ "$EC" -le 2 ]; then
  check 4 "§0 원가 철칙 (마진 ≥3.5×)" "WARN" "sensor-cost-margin WARN [ACCEPTABLE — 조기 경보 정상 신호, 책 Ch 18 cost-accountant 권장 임계 3.0~3.5× WARN]"
else
  check 4 "§0 원가 철칙 (마진 ≥3.5×)" "FAIL" "sensor-cost-margin FAIL (exit=$EC)"
fi

# Principle 5 — 외부 Anthropic API 보류 (사용자 0-1 결정)
ANTHROPIC_IMPORTS=$(grep -rE "from anthropic|import anthropic" "$ROOT/eval/scripts" "$ROOT/grimoire-server/src" 2>/dev/null | wc -l | tr -d ' ')
if [ "$ANTHROPIC_IMPORTS" -eq 0 ]; then
  check 5 "외부 Anthropic API 보류" "PASS" "anthropic SDK import 0건 (stub 유지)"
else
  check 5 "외부 Anthropic API 보류" "FAIL" "$ANTHROPIC_IMPORTS 건 anthropic import 검출 (사용자 0-1 결정 위반)"
fi

# Principle 6 — shared-contracts 정합
echo ""
echo "── 강제 규정 (Strict) ──"
bash "$ROOT/.claude/scripts/sensor-shared-contracts.sh" >/dev/null 2>&1
EC=$?
if [ "$EC" -eq 0 ]; then
  check 6 "shared-contracts 정합" "PASS" "10 인터페이스 + §4 변경 리뷰 PASS"
elif [ "$EC" -le 2 ]; then
  check 6 "shared-contracts 정합" "WARN" "shared-contracts WARN (exit=$EC)"
else
  check 6 "shared-contracts 정합" "FAIL" "shared-contracts FAIL (exit=$EC)"
fi

# Principle 7 — 분할 정본 ≤ 임계
INSTR_RESULT=$(bash "$ROOT/.claude/scripts/sensor-instruction-degradation.sh" >/dev/null 2>&1; echo $?)
case "$INSTR_RESULT" in
  0) check 7 "분할 정본 ≤ 임계" "PASS" "11 파일 모두 임계 이하" ;;
  1) check 7 "분할 정본 ≤ 임계" "WARN" "1+ 파일 임계 초과 (분할 권장)" ;;
  *) check 7 "분할 정본 ≤ 임계" "FAIL" "1.5× 임계 초과 (즉시 분할)" ;;
esac

# Principle 8 — Sensor 모두 PASS/WARN (lenient: exit ≤2 PASS, exit ≥3 FAIL — 우리 컨벤션)
# 2026-05-04 묶음 KK: PAY-P0 신규 sensor 3건 추가 (전수조사로 호출 누락 발견)
SENSOR_FAIL=0
for s in sensor-server sensor-web sensor-docs-sync sensor-secret-leak sensor-credit-atomicity \
         sensor-payment-idempotency sensor-payment-reconciliation sensor-admin-credit-ui; do
  bash "$ROOT/.claude/scripts/$s.sh" >/dev/null 2>&1
  EC=$?
  [ "$EC" -gt 2 ] && SENSOR_FAIL=$((SENSOR_FAIL+1))
done
if [ "$SENSOR_FAIL" -eq 0 ]; then
  check 8 "핵심 Sensor exit ≤2" "PASS" "8 핵심 sensor 모두 통과 (exit ≤2, PAY-P0 3건 포함)"
else
  check 8 "핵심 Sensor exit ≤2" "FAIL" "$SENSOR_FAIL 핵심 sensor exit ≥3 (FAIL)"
fi

# Principle 9 — Stop hook 메모리 절대 규칙
TODAY=$(date +%Y-%m-%d)
TODAY_COMPACT="${TODAY//-/}"
MEMORY_INDEX="$HOME/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/memory/MEMORY.md"
HAS_TODAY_COMMITS=$(git -C "$ROOT" log --since="$TODAY 00:00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$HAS_TODAY_COMMITS" -gt 0 ] && ! grep -q "$TODAY_COMPACT" "$MEMORY_INDEX" 2>/dev/null; then
  check 9 "Stop hook 메모리 박제" "WARN" "오늘 commit 있는데 MEMORY.md 미박제"
else
  check 9 "Stop hook 메모리 박제" "PASS" "정합 (또는 오늘 commit 0건)"
fi

# Principle 10 — 한국어 존댓말 (commit 메시지 한국어 비율 검사)
RECENT_KOR=$(git -C "$ROOT" log -10 --format=%B 2>/dev/null | grep -cE "[가-힣]" || echo 0)
if [ "$RECENT_KOR" -ge 5 ]; then
  check 10 "한국어 존댓말" "PASS" "최근 10 commit 중 ${RECENT_KOR}건 한국어 사용"
else
  check 10 "한국어 존댓말" "WARN" "최근 10 commit 중 한국어 ${RECENT_KOR}건 (≥5 권장)"
fi

# Principle 11 — Git main 직접 commit 금지
echo ""
echo "── Git/CI 규정 ──"
CURRENT_BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null)
if [ "$CURRENT_BRANCH" = "main" ]; then
  check 11 "Git main 직접 commit 금지" "FAIL" "현재 main 브랜치 — develop 사용 필수"
else
  check 11 "Git main 직접 commit 금지" "PASS" "현재 $CURRENT_BRANCH (main 아님)"
fi

# Principle 12 — Pre-push hook 우회 금지 (간접 검증)
HOOKS_PATH=$(git -C "$ROOT" config core.hooksPath 2>/dev/null)
if [ "$HOOKS_PATH" = ".githooks" ] || [ -z "$HOOKS_PATH" ]; then
  check 12 "Pre-push hook 우회 금지" "PASS" "core.hooksPath 정합 또는 default"
else
  check 12 "Pre-push hook 우회 금지" "WARN" "core.hooksPath=$HOOKS_PATH (검토)"
fi

# Principle 13 — 시크릿 평문 금지 (lenient)
echo ""
echo "── 보안 규정 ──"
bash "$ROOT/.claude/scripts/sensor-secret-leak.sh" >/dev/null 2>&1
EC=$?
if [ "$EC" -eq 0 ]; then
  check 13 "시크릿 평문 금지" "PASS" "sensor-secret-leak PASS"
elif [ "$EC" -le 2 ]; then
  check 13 "시크릿 평문 금지" "WARN" "sensor-secret-leak WARN (exit=$EC)"
else
  check 13 "시크릿 평문 금지" "FAIL" "시크릿 평문 검출 (exit=$EC)"
fi

# Principle 14 — BFF 프록시 강제
DIRECT_API_CALLS=$(grep -rE "fetch\(['\"]https?://api\.grimoire-book\.com|fetch\(['\"]https?://dev-api\." \
  "$ROOT/grimoire-web/src" --include="*.tsx" --include="*.ts" --exclude="*.spec.*" --exclude="*.test.*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRECT_API_CALLS" -eq 0 ]; then
  check 14 "BFF 프록시 강제" "PASS" "백엔드 URL 직접 호출 0건"
else
  check 14 "BFF 프록시 강제" "FAIL" "$DIRECT_API_CALLS 건 백엔드 직접 호출 (BFF /api/... 사용 필수)"
fi

# Principle 15 — HttpOnly Cookie 강제
LOCALSTORAGE_TOKEN=$(grep -rE "localStorage\.(setItem|getItem)\(['\"](token|jwt|access[_-]?token|refresh[_-]?token)" \
  "$ROOT/grimoire-web/src" --include="*.tsx" --include="*.ts" --exclude="*.spec.*" --exclude="*.test.*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$LOCALSTORAGE_TOKEN" -eq 0 ]; then
  check 15 "HttpOnly Cookie 강제" "PASS" "localStorage 토큰 저장 0건"
else
  check 15 "HttpOnly Cookie 강제" "FAIL" "$LOCALSTORAGE_TOKEN 건 localStorage 토큰 저장 (HttpOnly Cookie 강제)"
fi

# Principle 17 — LLM Prompt Injection 방어 (OWASP LLM01, 2026-05-03 묶음 CC)
# server controller에 prompt injection 의심 패턴 grep (sensor만 — controller 보강은 grimoire-server 사용자 결정)
# 정밀화 (#10_6 묶음 FF): grep 결과 file:content 형식 prefix 고려 — JSDoc 연속 라인 ` * ` 제외
INJECTION_PATTERNS=$(grep -rE "ignore previous instructions|system prompt|you are now|</prompt>" \
  "$ROOT/grimoire-server/src" --include="*.ts" --exclude="*.spec.ts" \
  --exclude="prompt-injection-guard.ts" 2>/dev/null \
  | grep -vE "^[^:]+:\s*//|^[^:]+:\s*\*|^[^:]+:\s*/\*|// SAFE:" \
  | wc -l | tr -d ' ')
if [ "$INJECTION_PATTERNS" -eq 0 ]; then
  check 17 "LLM Prompt Injection 방어 (OWASP LLM01)" "PASS" "controller에 의심 패턴 0건 (주석 false positive 제외)"
else
  check 17 "LLM Prompt Injection 방어 (OWASP LLM01)" "WARN" "$INJECTION_PATTERNS 건 의심 패턴 검출 (// SAFE: 마크 또는 controller 보강 권장)"
fi

# Principle 18 — LLM Output Encoding (OWASP LLM02, 2026-05-03 묶음 CC)
# grimoire-web에서 LLM 응답을 dangerouslySetInnerHTML로 렌더링하는지 (이미 정합 — 회귀 차단용)
DSI_LLM=$(grep -rE "dangerouslySetInnerHTML.*\b(ai|llm|claude|response)\b" \
  "$ROOT/grimoire-web/src" --include="*.tsx" --include="*.ts" --exclude="*.spec.*" --exclude="*.test.*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$DSI_LLM" -eq 0 ]; then
  check 18 "LLM Output Encoding (OWASP LLM02)" "PASS" "dangerouslySetInnerHTML + LLM 응답 패턴 0건"
else
  check 18 "LLM Output Encoding (OWASP LLM02)" "FAIL" "$DSI_LLM 건 검출 — XSS 위험"
fi

# Principle 19 — Sensitive Info Disclosure 강화 (OWASP LLM06, 2026-05-03 묶음 CC)
# 환경변수 직접 응답 / Prisma raw findMany / PII 평문 응답 검출
ENV_LEAK=$(grep -rE "res\.json.*process\.env|return.*process\.env" \
  "$ROOT/grimoire-server/src/adapter/inbound" --include="*.ts" --exclude="*.spec.ts" 2>/dev/null | wc -l | tr -d ' ')
if [ "$ENV_LEAK" -eq 0 ]; then
  check 19 "Sensitive Info Disclosure (OWASP LLM06)" "PASS" "controller에 process.env 직접 응답 0건"
else
  check 19 "Sensitive Info Disclosure (OWASP LLM06)" "FAIL" "$ENV_LEAK 건 환경변수 직접 응답 — 시크릿 노출 위험"
fi

# Principle 16 — 결제 원자성 (lenient — sensor-credit-atomicity가 WARN exit 2 컨벤션 사용)
bash "$ROOT/.claude/scripts/sensor-credit-atomicity.sh" >/dev/null 2>&1
EC=$?
if [ "$EC" -eq 0 ]; then
  check 16 "결제 원자성 (transaction)" "PASS" "sensor-credit-atomicity PASS"
elif [ "$EC" -le 2 ]; then
  check 16 "결제 원자성 (transaction)" "WARN" "sensor-credit-atomicity WARN [ACCEPTABLE — CreditLog audit는 server 도메인 사용자 결정 영역, J8/Phase δ 미해소]"
else
  check 16 "결제 원자성 (transaction)" "FAIL" "sensor-credit-atomicity FAIL (exit=$EC)"
fi

# 종합
echo ""
echo "── 종합 (19 Principles, OWASP LLM Top 10 통합) ──"
echo "PASS: $PASS / WARN: $WARN / FAIL: $FAIL (총 19)"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ Constitution 위반 — Commit 차단:"
  for p in "${FAIL_PRINCIPLES[@]}"; do
    echo "  - $p"
  done
  echo ""
  echo "💡 자가-비판 발동 권장 (Constitutional AI 패턴):"
  echo "   각 위반에 대해: 'Critique using principle [N]. Then revise.'"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-adversarial-pre-commit" "FAIL" "PASS=$PASS WARN=$WARN FAIL=$FAIL" 2>/dev/null || true
  exit 2
elif [ "$WARN" -gt 0 ]; then
  echo ""
  echo "⚠️ WARN ${WARN}건 — 검토 권장 (commit 허용)"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-adversarial-pre-commit" "WARN" "PASS=$PASS WARN=$WARN FAIL=$FAIL" 2>/dev/null || true
  exit 1
else
  echo ""
  echo "✅ 16 Principles 모두 PASS — Commit 허용 (Constitutional AI 정합)"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-adversarial-pre-commit" "PASS" "PASS=$PASS WARN=$WARN FAIL=$FAIL" 2>/dev/null || true
  exit 0
fi
