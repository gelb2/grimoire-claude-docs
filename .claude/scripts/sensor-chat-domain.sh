#!/bin/bash
# sensor-chat-domain.sh — chat 도메인 회귀 차단 sensor (묶음 OO-1)
#
# 사용자 명시 (2026-05-06): 레드팀이 다른 에이전트 영역 안 한 곳 공격 가능 검증.
# chat 도메인 sensor 0건 발견 → 본 sensor로 회귀 차단.
#
# 검증 대상 (chat usecase + controller):
#   1. guardPromptInjection import + 호출 박제 (P17 OWASP LLM01)
#   2. CHAT_SYSTEM_PROMPT 시스템 프롬프트 정합 (절대 규칙 4개 + 역할 3개)
#   3. ClaudeApiPort 의존성 (Hexagonal Port 정합)
#   4. 작가 본인 검증 (ForbiddenException) — chat session 소유권
#   5. session 존재 검증 (NotFoundException)
#   6. 세션 삭제 시 소유권 재검증
#   7. RAG 통합 (vectorStore.searchSimilar 호출)
#   8. context + instructions 시스템 프롬프트 주입 (Work 메타)
#   9. 에피소드 매니페스트 자동 생성 (ep1/ep2 같은 환각 방지)
#  10. 대화 히스토리 최근 10개 (컨텍스트 한도)
#  11. spec 파일 jest 통과 (회귀 자동 검증)
#
# Exit codes:
#   0 PASS / 1 FAIL

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
USECASE="$ROOT/grimoire-server/src/application/chat/chat.usecase.ts"
CONTROLLER="$ROOT/grimoire-server/src/adapter/inbound/http/controller/chat.controller.ts"

PASS=0
FAIL=0

echo "=== sensor-chat-domain (묶음 OO-1) ==="
echo ""

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "PASS" ]; then
    echo "  [PASS] $desc"; PASS=$((PASS+1))
  else
    echo "  [FAIL] $desc"; FAIL=$((FAIL+1))
  fi
}

# 1. guardPromptInjection import + 호출
if grep -q "import.*guardPromptInjection" "$USECASE" 2>/dev/null && grep -q "guardPromptInjection(userMessage" "$USECASE" 2>/dev/null; then
  check "P17 guardPromptInjection import + sendMessage 호출 박제" PASS
else
  check "P17 guardPromptInjection 누락 (P17 회귀 위험)" FAIL
fi

# 2. CHAT_SYSTEM_PROMPT 절대 규칙 4개
if grep -q "CHAT_SYSTEM_PROMPT" "$USECASE" 2>/dev/null; then
  rule_count=$(grep -cE "^[0-9]+\.|=== 절대 규칙" "$USECASE" 2>/dev/null | head -1 | tr -d ' \n')
  if grep -q "원고에 명시적으로 나오는 정보만\|추론이나 상상으로\|확인할 수 없는 정보는\|추측 표현을 사용하지" "$USECASE" 2>/dev/null; then
    check "CHAT_SYSTEM_PROMPT 절대 규칙 4개 박제 (환각 차단)" PASS
  else
    check "CHAT_SYSTEM_PROMPT 절대 규칙 일부 누락 (환각 위험)" FAIL
  fi
else
  check "CHAT_SYSTEM_PROMPT 자체 부재" FAIL
fi

# 3. ClaudeApiPort 의존성 (Hexagonal Port)
if grep -q "ClaudeApiPort" "$USECASE" 2>/dev/null; then
  check "ClaudeApiPort 의존성 (Hexagonal Port 정합)" PASS
else
  check "ClaudeApiPort 누락 (Hexagonal 위반 — 직접 anthropic SDK 의심)" FAIL
fi

# 4. 작가 본인 검증 (ForbiddenException)
if grep -q "ForbiddenException.*본인의 채팅\|session.authorId !== authorId" "$USECASE" 2>/dev/null; then
  check "session 소유권 ForbiddenException 박제" PASS
else
  check "session 소유권 검증 누락 (IDOR 위험)" FAIL
fi

# 5. session 존재 검증
if grep -q "NotFoundException.*채팅 세션을 찾을 수 없" "$USECASE" 2>/dev/null; then
  check "session NotFoundException 박제" PASS
else
  check "session 존재 검증 누락" FAIL
fi

# 6. 세션 삭제 시 소유권 재검증
if grep -A10 "deleteSession" "$USECASE" 2>/dev/null | grep -q "authorId !== authorId\|본인의 채팅만 삭제"; then
  check "deleteSession 소유권 재검증 박제" PASS
else
  check "deleteSession 소유권 재검증 누락 (다른 사용자 채팅 삭제 위험)" FAIL
fi

# 7. RAG 통합 (vectorStore.searchSimilar)
if grep -q "vectorStore.searchSimilar" "$USECASE" 2>/dev/null; then
  check "RAG vectorStore.searchSimilar 통합 박제" PASS
else
  check "RAG 통합 누락 (원고 맥락 없는 응답 위험)" FAIL
fi

# 8. context + instructions 시스템 프롬프트 주입
if grep -qE "workContext|workInstructions" "$USECASE" 2>/dev/null; then
  check "Work context + instructions 시스템 프롬프트 주입 박제" PASS
else
  check "Work 메타 주입 누락 (작품별 맞춤 응답 X)" FAIL
fi

# 9. 에피소드 매니페스트 자동 생성 (환각 방지)
if grep -qE "episodeManifest|에피소드 목록 \(정확히 이것만 존재" "$USECASE" 2>/dev/null; then
  check "episodeManifest 자동 생성 박제 (없는 에피소드 환각 방지)" PASS
else
  check "episodeManifest 누락 (없는 에피소드를 만드는 환각 위험)" FAIL
fi

# 10. 대화 히스토리 최근 10개 (컨텍스트 한도)
if grep -qE "getRecentMessages\(.*,\s*10\)" "$USECASE" 2>/dev/null; then
  check "대화 히스토리 10개 한도 박제 (컨텍스트 폭주 차단)" PASS
else
  check "대화 히스토리 한도 누락 (컨텍스트 폭주 위험)" FAIL
fi

# 11. spec 파일 jest 통과 (회귀 자동 검증)
SPEC="$ROOT/grimoire-server/src/application/chat/chat.usecase.spec.ts"
if [ -f "$SPEC" ]; then
  cd "$ROOT/grimoire-server" && npx jest src/application/chat/chat.usecase.spec.ts --silent >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    check "chat.usecase.spec.ts jest 통과 (회귀 자동 검증)" PASS
  else
    check "chat.usecase.spec.ts jest FAIL (회귀 검출)" FAIL
  fi
else
  check "chat.usecase.spec.ts 자체 부재" FAIL
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

# sensor-log 박제 (옵저버빌리티)
if [ -x "$ROOT/.claude/scripts/sensor-log.sh" ]; then
  TAG="PASS"; [ "$FAIL" -gt 0 ] && TAG="FAIL"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-chat-domain" "$TAG" "PASS=$PASS FAIL=$FAIL" 2>/dev/null || true
fi

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — chat 도메인 회귀 검출"
  exit 1
fi

echo "[RESULT] PASS — chat 도메인 정합 (P17 + 환각 방지 + Hexagonal + IDOR 차단)"
exit 0
