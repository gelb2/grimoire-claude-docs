#!/usr/bin/env bash
# sensor-oauth-email-verification — 트랙 F (sprint #10_7) OAuth 자동 링크 보안 강화 회귀 차단
#
# 발동 조건:
# - pre-commit / pre-push (server 변경 시)
# - 정기 회귀 (eval-runner)
#
# 정본 (단일 진실):
# - `reports/sprint-oauth-email-verification-progress.md` §2 AC-1~AC-5
# - `.claude/shared-contracts.md` §16 OAuthEmailVerification
# - RFC 6819 §5.1.1 / OWASP A07:2021 (Authentication Failures)
#
# 검증 영역 (8건):
# 1. auth.usecase.ts에 email_verified === false 차단 패턴 박제
# 2. UnauthorizedException 메시지에 "Google 이메일이 아직 인증되지 않았습니다" 박제
# 3. payload.email_verified 검증이 findBySocialAccount 호출보다 앞에 위치 (자동 링크 차단)
# 4. spec 박제: googleLogin describe 블록 + email_verified=false 시나리오 it 박제
# 5. spec 박제: email_verified=true 회귀 보존 it 박제
# 6. spec 박제: payload.email 누락 시 UnauthorizedException it 박제
# 7. 외부 프로젝트 인용 0건 (CERTI_PROJ / brightmall / thermage / inapi)
# 8. spec 더미 assertion 차단 (toHaveBeenCalledWith / toMatchObject 의미 ≥3건)
#
# Exit codes:
# - 0 PASS — 모두 정합
# - 2 FAIL — 회귀 검출 (commit 차단)

# sensor-log 자동 박제 (트랙 1-A 패턴 정합)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set +e

REPO_ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER="$REPO_ROOT/grimoire-server"
USECASE="$SERVER/src/application/auth/auth.usecase.ts"
SPEC="$SERVER/src/application/auth/auth.usecase.spec.ts"

echo "── sensor-oauth-email-verification (트랙 F 강화안 A 회귀 차단) ──"

PASS=0
FAIL=0

# [1/8] email_verified === false 차단 패턴
if grep -nE 'payload\.email_verified\s*===\s*false' "$USECASE" > /dev/null 2>&1; then
  echo "  ✓ [1/8] email_verified === false 차단 패턴 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [1/8] email_verified === false 차단 패턴 누락"
  FAIL=$((FAIL+1))
fi

# [2/8] 차단 메시지 박제 (한국어 존댓말 정책 정합)
if grep -nE 'Google 이메일이 아직 인증되지 않았습니다' "$USECASE" > /dev/null 2>&1; then
  echo "  ✓ [2/8] 사용자 안내 메시지 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [2/8] 사용자 안내 메시지 누락"
  FAIL=$((FAIL+1))
fi

# [3/8] 검증이 findBySocialAccount 호출보다 앞에 위치 (자동 링크 차단)
EMAIL_VERIFIED_LINE=$(grep -nE 'payload\.email_verified\s*===\s*false' "$USECASE" | head -1 | cut -d: -f1)
FIND_SOCIAL_LINE=$(grep -nE 'findBySocialAccount' "$USECASE" | head -1 | cut -d: -f1)
if [ -n "$EMAIL_VERIFIED_LINE" ] && [ -n "$FIND_SOCIAL_LINE" ] && [ "$EMAIL_VERIFIED_LINE" -lt "$FIND_SOCIAL_LINE" ]; then
  echo "  ✓ [3/8] 차단 게이트가 findBySocialAccount 앞에 위치 (line $EMAIL_VERIFIED_LINE < $FIND_SOCIAL_LINE)"
  PASS=$((PASS+1))
else
  echo "  ✗ [3/8] 차단 게이트 위치 오류 (email_verified=$EMAIL_VERIFIED_LINE / findBySocialAccount=$FIND_SOCIAL_LINE)"
  FAIL=$((FAIL+1))
fi

# [4/8] spec googleLogin describe 박제 + email_verified=false 시나리오
if grep -nE "describe\(['\"]googleLogin" "$SPEC" > /dev/null 2>&1 && \
   grep -nE "email_verified.*false.*UnauthorizedException|email_verified=false" "$SPEC" > /dev/null 2>&1; then
  echo "  ✓ [4/8] spec googleLogin describe + email_verified=false 시나리오 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [4/8] spec googleLogin email_verified=false 시나리오 누락"
  FAIL=$((FAIL+1))
fi

# [5/8] spec email_verified=true 회귀 보존 it
if grep -nE "email_verified.*true.*정상|email_verified: true" "$SPEC" > /dev/null 2>&1; then
  echo "  ✓ [5/8] spec email_verified=true 회귀 보존 it 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [5/8] spec email_verified=true 회귀 보존 it 누락"
  FAIL=$((FAIL+1))
fi

# [6/8] spec payload.email 누락 시나리오
if grep -nE "payload\.email 없을 때|email 없을 때.*Unauthorized" "$SPEC" > /dev/null 2>&1; then
  echo "  ✓ [6/8] spec payload.email 누락 시나리오 박제"
  PASS=$((PASS+1))
else
  echo "  ✗ [6/8] spec payload.email 누락 시나리오 누락"
  FAIL=$((FAIL+1))
fi

# [7/8] 외부 프로젝트 인용 0건
EXT_HITS=$(grep -rEi 'CERTI_PROJ|brightmall|thermage|inapi' "$USECASE" "$SPEC" 2>/dev/null)
if [ -z "$EXT_HITS" ]; then
  echo "  ✓ [7/8] 외부 프로젝트 인용 0건 (CERTI_PROJ / brightmall / thermage / inapi)"
  PASS=$((PASS+1))
else
  echo "  ✗ [7/8] 외부 프로젝트 인용 검출"
  echo "$EXT_HITS" | head -3
  FAIL=$((FAIL+1))
fi

# [8/8] spec 더미 assertion 차단 — googleLogin 영역 내 의미 있는 assertion ≥3건
GOOGLELOGIN_BLOCK=$(awk '/describe.*googleLogin/,/^  \}\)/' "$SPEC")
ASSERT_COUNT=$(echo "$GOOGLELOGIN_BLOCK" | grep -cE 'toHaveBeenCalledWith|toMatchObject|not\.toHaveBeenCalled|toThrow\(/')
if [ "$ASSERT_COUNT" -ge 3 ]; then
  echo "  ✓ [8/8] 의미 있는 assertion ≥3건 (toHaveBeenCalledWith/toMatchObject/not.toHaveBeenCalled = $ASSERT_COUNT건)"
  PASS=$((PASS+1))
else
  echo "  ✗ [8/8] 의미 있는 assertion 부족 ($ASSERT_COUNT건 < 3)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "── 종합 ──"
echo "  PASS: $PASS / FAIL: $FAIL"

if [ $FAIL -gt 0 ]; then
  echo "  ✗ FAIL — 트랙 F 회귀 검출 (commit 차단)"
  echo "  → 정본: reports/sprint-oauth-email-verification-progress.md §2 AC-1~AC-5"
  exit 2
fi

echo "  ✓ PASS — OAuth email_verified 차단 정합"
exit 0
