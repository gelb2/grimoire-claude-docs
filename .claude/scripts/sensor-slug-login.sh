#!/usr/bin/env bash
# sensor-slug-login — EMAIL-P0-3 slug 로그인 마이그레이션 회귀 차단
#
# 발동 조건:
# - pre-commit / pre-push (server + web 변경 시)
# - 정기 회귀 (eval-runner)
#
# 정본 (단일 진실):
# - `reports/sprint-email-p0-3-slug-login-progress.md` §2 AC-1~AC-7
# - `.claude/shared-contracts.md` §15 SlugLogin
#
# 검증 영역 (12건):
# 1. LoginDto email/slug @IsOptional 박제
# 2. EmailXorSlugConstraint validator 박제
# 3. AuthUseCase.login(input) 시그니처 — email?/slug?/password
# 4. login() 도메인 XOR 검증 (transport 우회 차단)
# 5. findByEmail ?? findBySlug 분기
# 6. AccessLog identifierType detail 박제
# 7. spec PAY-P0-3 / EMAIL-P0-3 describe 박제
# 8. spec ≥6 의미 있는 assertion (toHaveBeenCalledWith)
# 9. Web login/page.tsx 입력칸 1개 통합 + 자동 판별 정규식
# 10. Web lib/api.ts login() 시그니처 확장
# 11. e2e .env.example E2E_AUTHOR_SLUG 박제
# 12. 외부 프로젝트 인용 0건 (server src/docs + web src/e2e)
#
# Exit codes:
# - 0 PASS — 모두 정합
# - 1 WARN — 일부 정책 미준수 (commit 허용)
# - 2 FAIL — AC 미충족 (commit 차단)

# sensor-log 자동 박제 (트랙 1-A 보강 — exit code 자동 매핑: 0=PASS / 1=FAIL / 2=WARN)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 2

SERVER="grimoire-server"
WEB="grimoire-web"

if [ ! -d "$SERVER" ] || [ ! -d "$WEB" ]; then
  echo "  ⚠ grimoire-server/web 디렉토리 누락 — sensor 면제"
  exit 0
fi

echo "── sensor-slug-login (EMAIL-P0-3 회귀 차단) ──"

PASS=0
FAIL=0

check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✓ $desc"
    PASS=$((PASS+1))
  else
    echo "  ✗ $desc"
    FAIL=$((FAIL+1))
  fi
}

# 1. LoginDto email/slug @IsOptional
check "[1/12] LoginDto email + slug @IsOptional 박제" \
  bash -c "grep -nE 'class LoginDto' '$SERVER/src/adapter/inbound/http/dto/auth.dto.ts' >/dev/null && grep -A 10 'class LoginDto' '$SERVER/src/adapter/inbound/http/dto/auth.dto.ts' | grep -qE '@IsOptional'"

# 2. EmailXorSlugConstraint validator
check "[2/12] EmailXorSlugConstraint validator 박제" \
  grep -qE 'EmailXorSlugConstraint|EmailXorSlug' "$SERVER/src/adapter/inbound/http/dto/auth.dto.ts"

# 3. AuthUseCase.login 시그니처
check "[3/12] AuthUseCase.login(input) 시그니처 (email? + slug? + password)" \
  bash -c "grep -E 'async login\\(input:' '$SERVER/src/application/auth/auth.usecase.ts' | grep -qE 'email\\?|slug\\?'"

# 4. 도메인 XOR 검증
check "[4/12] login() 도메인 XOR 검증 (input.email && input.slug)" \
  grep -qE 'input\.email && input\.slug' "$SERVER/src/application/auth/auth.usecase.ts"

# 5. findByEmail ?? findBySlug 분기
check "[5/12] findByEmail / findBySlug 분기 박제" \
  bash -c "grep -qE 'findByEmail.*input\\.email' '$SERVER/src/application/auth/auth.usecase.ts' && grep -qE 'findBySlug.*input\\.slug' '$SERVER/src/application/auth/auth.usecase.ts'"

# 6. AccessLog identifierType detail
check "[6/12] AccessLog identifierType detail 박제 (controller)" \
  grep -qE 'identifierType' "$SERVER/src/adapter/inbound/http/controller/auth.controller.ts"

# 7. spec describe 박제
check "[7/12] spec PAY-P0-3 / EMAIL-P0-3 describe 박제" \
  grep -qE 'EMAIL-P0-3|slug 로그인' "$SERVER/src/application/auth/auth.usecase.spec.ts"

# 8. spec assertion ≥6
ASSERT_COUNT=$(grep -cE "toHaveBeenCalledWith|toHaveBeenCalledTimes|toEqual" "$SERVER/src/application/auth/auth.usecase.spec.ts" 2>/dev/null || echo 0)
if [ "$ASSERT_COUNT" -ge 6 ]; then
  echo "  ✓ [8/12] 의미 있는 assertion ≥6건 ($ASSERT_COUNT)"
  PASS=$((PASS+1))
else
  echo "  ✗ [8/12] 의미 있는 assertion 부족 ($ASSERT_COUNT < 6)"
  FAIL=$((FAIL+1))
fi

# 9. Web login/page.tsx 입력칸 1개 통합 + 자동 판별
check "[9/12] Web login/page.tsx 자동 판별 정규식 박제" \
  bash -c "grep -qE 'isEmail|emailOrSlug|이메일 또는' '$WEB/src/app/login/page.tsx'"

# 10. Web api.ts login 시그니처 확장
check "[10/12] Web lib/api.ts login 시그니처 (email? + slug?)" \
  bash -c "grep -A 5 'login.*data' '$WEB/src/lib/api.ts' | grep -qE 'slug'"

# 11. .env.example E2E_AUTHOR_SLUG
check "[11/12] Web .env.example E2E_AUTHOR_SLUG 박제" \
  grep -qE 'E2E_AUTHOR_SLUG' "$WEB/.env.example"

# 12. 외부 프로젝트 인용 0건
EXT_HITS=$(grep -rE 'CERTI_PROJ|brightmall|thermage|inapi|admin-certilife|no1-sass' \
  "$SERVER/src" "$SERVER/docs" "$WEB/src" "$WEB/e2e" \
  2>/dev/null || true)

if [ -z "$EXT_HITS" ]; then
  echo "  ✓ [12/12] 외부 프로젝트 인용 0건 (server src/docs + web src/e2e)"
  PASS=$((PASS+1))
else
  echo "  ✗ [12/12] 외부 프로젝트 인용 검출"
  echo "$EXT_HITS" | head -3
  FAIL=$((FAIL+1))
fi

echo ""
echo "── 종합 ──"
echo "  PASS: $PASS / FAIL: $FAIL"

if [ $FAIL -gt 0 ]; then
  echo "  ✗ FAIL — EMAIL-P0-3 회귀 검출 (commit 차단)"
  echo "  → 정본: reports/sprint-email-p0-3-slug-login-progress.md §2 AC-1~AC-7"
  exit 2
fi

echo "  ✓ PASS — EMAIL-P0-3 모든 검증 정합"
exit 0
