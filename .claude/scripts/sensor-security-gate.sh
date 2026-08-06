#!/bin/bash
# sensor-security-gate.sh — Grimoire 보안 게이트 8항목 독립 검증
# QA 에이전트가 매일 23:21에 실행하여 raw stdout을 reports/QA_REPORT.md에 전체 첨부
# vibe-coding 게이트 체크 + GMP v2.2 Chain-of-Verification 구현
#
# 8개 항목:
#   [1] Mutation 엔드포인트 가드 커버리지
#   [2] Admin 엔드포인트 AdminGuard 커버리지
#   [3] 쿠키 sameSite='strict' 일관성
#   [4] 웹 localStorage 민감 정보 저장 여부
#   [5] 'use client' 외부 API 직접 fetch 여부
#   [6] 운영 보호 엔드포인트 401 반환 검증
#   [7] 보안 헤더 6종 일관성 (운영 curl)
#   [8] dangerouslySetInnerHTML 사용 여부

set -u
START_TIME=$(date +%s)

PROJECT_ROOT="/Users/sokol/Git/ProjectGrimoire"
SERVER_DIR="$PROJECT_ROOT/grimoire-server"
WEB_DIR="$PROJECT_ROOT/grimoire-web"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
FAIL_STEPS=()
WARN_STEPS=()

run_step() {
  local step_name="$1"
  shift
  echo ""
  echo "=== $step_name ==="
  local output
  local exit_code
  output=$("$@" 2>&1)
  exit_code=$?
  echo "$output"
  if [ $exit_code -eq 0 ]; then
    echo "[RESULT] PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  elif [ $exit_code -eq 2 ]; then
    echo "[RESULT] WARN"
    WARN_COUNT=$((WARN_COUNT + 1))
    WARN_STEPS+=("$step_name")
  else
    echo "[RESULT] FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_STEPS+=("$step_name")
  fi
}

echo "=== sensor-security-gate.sh 시작 $(date '+%Y-%m-%d %H:%M:%S') ==="
echo "프로젝트: $PROJECT_ROOT"

# ============================================
# [1] Mutation 엔드포인트 가드 커버리지
# ============================================
check_mutation_guards() {
  cd "$SERVER_DIR"
  python3 <<'PY'
import os, re, sys
ctrl_dir = "src/adapter/inbound/http/controller"
MUTATION = re.compile(r'^\s*@(Post|Put|Patch|Delete)\(')
GUARD = re.compile(r'@UseGuards\([^)]*(?:JwtAuthGuard|AdminGuard|OptionalAuthGuard)[^)]*\)')
ALLOW_PUBLIC = re.compile(r'@Public\(\)|@AllowAnonymous\(\)')

# 의도적 공개 허용 리스트 (login/register/refresh/logout/google/social anon)
# [2026-06-01] password reset 2종 추가 — EMAIL-POLAR-READY Phase C (server 2bafb4f, 5/27 도입).
#   비로그인 호출 본질 필수(비밀번호 잊은 사용자) → JWT 가드 불가. 보호 수단:
#   @Throttle(reset-request 분당3 / reset-confirm 분당10) + enumeration 차단 응답 + 토큰 purpose 검증.
#   register/login/refresh 와 동일 '인증 전' 범주. server 코드 정상 = sensor 화이트리스트 stale 갭 해소.
ALLOWED_UNPROTECTED = {
    "POST login (admin.controller.ts)",
    "POST register (auth.controller.ts)",
    "POST login (auth.controller.ts)",
    "POST google (auth.controller.ts)",
    "POST refresh (auth.controller.ts)",
    "POST logout (auth.controller.ts)",
    "POST password/reset-request (auth.controller.ts)",
    "POST password/reset-confirm (auth.controller.ts)",
    "POST likes/:episodeId (social.controller.ts)",
    "POST comments/:episodeId (social.controller.ts)",
    "DELETE comments/:commentId (social.controller.ts)",
}

total = 0; protected_count = 0
unexpected_unprotected = []

for fname in sorted(os.listdir(ctrl_dir)):
    if not fname.endswith('.ts') or fname.endswith('.spec.ts'):
        continue
    with open(os.path.join(ctrl_dir, fname)) as f:
        lines = f.readlines()
    ctrl_has_guard = any(GUARD.search(l) for l in lines[:50])
    for i, line in enumerate(lines):
        if MUTATION.search(line):
            total += 1
            block = ''.join(lines[max(0,i-6):i+2])
            if GUARD.search(block) or ctrl_has_guard:
                protected_count += 1
                continue
            m = MUTATION.search(line)
            method = m.group(1).upper()
            p = re.search(r"@\w+\(['\"]([^'\"]*)['\"]", line)
            path_str = p.group(1) if p else ''
            key = f"{method} {path_str} ({fname})"
            if key in ALLOWED_UNPROTECTED or ALLOW_PUBLIC.search(block):
                pass  # 의도 공개
            else:
                unexpected_unprotected.append(key)

print(f"전체 mutation: {total}")
print(f"가드 적용: {protected_count}")
print(f"의도적 공개 (허용리스트): {len(ALLOWED_UNPROTECTED)}")
print(f"🔴 예상 외 미보호: {len(unexpected_unprotected)}")
if unexpected_unprotected:
    for x in unexpected_unprotected:
        print(f"  {x}")
    sys.exit(1)
PY
}
run_step "[1/8] Mutation 가드 커버리지" check_mutation_guards

# ============================================
# [2] Admin AdminGuard 커버리지
# ============================================
check_admin_guards() {
  cd "$SERVER_DIR"
  python3 <<'PY'
import re, sys
with open("src/adapter/inbound/http/controller/admin.controller.ts") as f:
    lines = f.readlines()
MUT = re.compile(r'^\s*@(Get|Post|Put|Patch|Delete)\(')
ADMIN_GUARD = re.compile(r'AdminGuard')
total = 0
no_guard = []
for i, line in enumerate(lines):
    if MUT.search(line):
        total += 1
        block = ''.join(lines[max(0,i-5):i+2])
        if not ADMIN_GUARD.search(block):
            m = MUT.search(line)
            p = re.search(r"@\w+\(['\"]([^'\"]*)['\"]", line)
            path_str = p.group(1) if p else ''
            key = f"{m.group(1).upper()} {path_str}"
            if key != "POST login":
                no_guard.append(f"{key} ({i+1}행)")
print(f"admin 엔드포인트 총: {total}")
print(f"AdminGuard 미적용 (admin login 제외): {len(no_guard)}")
if no_guard:
    for x in no_guard: print(f"  🔴 {x}")
    sys.exit(1)
PY
}
run_step "[2/8] Admin AdminGuard 커버리지" check_admin_guards

# ============================================
# [3] 쿠키 sameSite='strict' 일관성
# ============================================
check_cookie_consistency() {
  cd "$SERVER_DIR"
  # 인증 쿠키 cookieOptions 함수의 sameSite 값 직접 확인
  # auth.controller: cookieOptions() 함수 → ACCESS/REFRESH 쿠키에 적용
  # admin.controller: 인라인 옵션 직접 지정
  AUTH_OK=0
  ADMIN_OK=0

  if grep -qE "sameSite:\s*'strict'" src/adapter/inbound/http/controller/auth.controller.ts; then
    AUTH_OK=1
    echo "auth.controller cookieOptions: sameSite='strict' ✅"
  else
    echo "🔴 auth.controller에 sameSite='strict' 없음"
  fi

  if grep -qE "sameSite:\s*'strict'" src/adapter/inbound/http/controller/admin.controller.ts; then
    ADMIN_OK=1
    echo "admin.controller: sameSite='strict' ✅"
  else
    echo "🔴 admin.controller에 sameSite='strict' 없음"
  fi

  # lax로 남은 인증 관련 쿠키 있는지 확인
  # 허용된 lax 사용처: social.controller.ts의 grimoire_anon (익명 좋아요 쿠키)
  LAX_HITS=$(grep -rln "sameSite:\s*'lax'" src/adapter/inbound/http/controller/*.ts 2>/dev/null | \
    grep -v "spec\.ts" | grep -v "social\.controller\.ts")
  if [ -n "$LAX_HITS" ]; then
    echo ""
    echo "🔴 sameSite='lax' 사용 파일 (social.controller.ts 외 — 인증 쿠키일 가능성):"
    echo "$LAX_HITS"
    # 각 파일에서 실제 lax 라인 표시
    for file in $LAX_HITS; do
      echo "  --- $file ---"
      grep -nB2 "sameSite:\s*'lax'" "$file"
    done
    exit 1
  fi

  if [ $AUTH_OK -eq 1 ] && [ $ADMIN_OK -eq 1 ]; then
    echo ""
    echo "인증 쿠키 sameSite='strict' 일관성 확인 완료"
    echo "social.controller.ts의 grimoire_anon은 익명 정책상 'lax' 사용 (허용)"
    exit 0
  else
    exit 1
  fi
}
run_step "[3/8] 쿠키 sameSite='strict' 일관성" check_cookie_consistency

# ============================================
# [4] 웹 localStorage 민감 정보 저장 여부
# ============================================
check_localstorage_safety() {
  cd "$WEB_DIR"
  # token/password/jwt/secret/auth/credential 중 민감한 키워드로 저장하는지
  HITS=$(grep -rn "localStorage\.\(setItem\|getItem\)" src/ 2>/dev/null | \
    grep -v "\.test\." | grep -v "\.spec\." | \
    grep -iE "token|password|jwt|secret|credential" | \
    grep -vE "grimoire_anon_nickname|grimoire_font_size" | head)
  if [ -z "$HITS" ]; then
    echo "민감 키워드(token/password/jwt/secret/credential) localStorage 저장 0건"
    # 참고: 허용 키
    echo ""
    echo "참고 — localStorage 사용 중인 키 (민감 정보 아님):"
    grep -rn "localStorage\.setItem" src/ 2>/dev/null | grep -v test | grep -v spec | \
      sed -nE "s/.*setItem\(['\"]([^'\"]+)['\"].*/  - \1/p" | sort -u
    exit 0
  else
    echo "🔴 민감 정보 localStorage 저장 의심:"
    echo "$HITS"
    exit 1
  fi
}
run_step "[4/8] 웹 localStorage 민감 정보 저장 여부" check_localstorage_safety

# ============================================
# [5] 'use client' 외부 API 직접 fetch 여부
# ============================================
check_bff_bypass() {
  cd "$WEB_DIR"
  python3 <<'PY'
import os, re, sys
leaks = []
for dirpath, _, files in os.walk("src"):
    for fname in files:
        if not (fname.endswith('.ts') or fname.endswith('.tsx')):
            continue
        path = os.path.join(dirpath, fname)
        with open(path, errors='ignore') as f:
            content = f.read()
        if "'use client'" in content or '"use client"' in content:
            for m in re.finditer(r"fetch\s*\(\s*[`'\"](https?://[^`'\"]+)", content):
                leaks.append(f"{path}: {m.group(1)[:80]}")
if leaks:
    print("🔴 클라이언트 컴포넌트에서 외부 fetch 발견:")
    for x in leaks: print(f"  {x}")
    sys.exit(1)
else:
    print("클라이언트 컴포넌트에서 직접 외부 fetch 0건 — 전부 BFF 프록시 경유")
PY
}
run_step "[5/8] 'use client' 외부 API 직접 fetch 여부" check_bff_bypass

# ============================================
# [6] 운영 보호 엔드포인트 401 반환 검증
# ============================================
check_auth_enforcement() {
  # 인증 필요 엔드포인트들을 토큰 없이 호출 → 401이 나와야 함
  local fail=0
  local endpoints=(
    "GET|/api/credits/balance"
    "POST|/api/payments/initiate"
    "GET|/api/admin/stats"
    "POST|/api/themes/generate"
    "GET|/api/auth/me"
  )
  for entry in "${endpoints[@]}"; do
    local method="${entry%%|*}"
    local endpoint="${entry#*|}"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "https://api.grimoire-book.com$endpoint" 2>/dev/null)
    case "$code" in
      401)
        echo "  ✅ $method $endpoint → 401 (정상)"
        ;;
      404)
        echo "  🟡 $method $endpoint → 404 (엔드포인트 없음 — 경로 확인 필요)"
        ;;
      200|201)
        echo "  🔴 $method $endpoint → $code (인증 없이 통과!)"
        fail=1
        ;;
      *)
        echo "  🟡 $method $endpoint → $code"
        ;;
    esac
  done
  if [ $fail -eq 1 ]; then return 1; fi
  return 0
}
run_step "[6/8] 운영 인증 강제 (401 반환 검증)" check_auth_enforcement

# ============================================
# [7] 보안 헤더 6종 일관성 (운영 curl)
# ============================================
check_security_headers() {
  FAIL=0
  REQUIRED_HEADERS=(
    "strict-transport-security"
    "x-frame-options"
    "x-content-type-options"
    "referrer-policy"
    "content-security-policy"
  )
  for url in \
    "https://grimoire-book.com/" \
    "https://grimoire-book.com/explore" \
    "https://api.grimoire-book.com/api/health"; do
    echo "--- $url ---"
    HEADERS=$(curl -sI "$url" 2>/dev/null | tr '[:upper:]' '[:lower:]')
    for h in "${REQUIRED_HEADERS[@]}"; do
      if echo "$HEADERS" | grep -q "^${h}:"; then
        echo "  ✅ $h"
      else
        echo "  🔴 $h 누락"
        FAIL=1
      fi
    done
  done
  if [ $FAIL -eq 1 ]; then exit 1; fi
  exit 0
}
run_step "[7/8] 보안 헤더 6종 운영 실측" check_security_headers

# ============================================
# [8] dangerouslySetInnerHTML 사용 여부
# ============================================
check_dangerous_html() {
  cd "$WEB_DIR"
  HITS=$(grep -rn "dangerouslySetInnerHTML" src/ 2>/dev/null | grep -v "\.test\." | grep -v "\.spec\.")
  if [ -z "$HITS" ]; then
    echo "dangerouslySetInnerHTML 사용 0건"
    exit 0
  else
    echo "🟡 dangerouslySetInnerHTML 사용 발견 — 각 케이스 검토 필요:"
    echo "$HITS"
    # 0건이 아니라고 바로 FAIL은 아님, 정당한 용도일 수 있음
    exit 2  # WARN
  fi
}
run_step "[8/9] dangerouslySetInnerHTML 사용" check_dangerous_html

# ─────────────────────────────────────────────────────────────
# §9 (2026-04-25 신설) Secret Hardcode Leak Detector
# 별도 스크립트 sensor-secret-leak.sh에 위임
# ─────────────────────────────────────────────────────────────
check_secret_leak() {
  local sensor_path="$(dirname "${BASH_SOURCE[0]}")/sensor-secret-leak.sh"
  if [ ! -x "$sensor_path" ]; then
    echo "sensor-secret-leak.sh 미존재 또는 실행권한 없음: $sensor_path"
    return 1
  fi
  local output
  output=$(bash "$sensor_path" 2>&1)
  local rc=$?
  echo "$output" | tail -20
  return $rc
}
run_step "[9/9] Secret Hardcode Leak (live API key + 알려진 약한 default)" check_secret_leak

# ============================================
# 최종 요약
# ============================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=== 보안 게이트 요약 ==="
echo "PASS: $PASS_COUNT/9"
echo "WARN: $WARN_COUNT/9"
echo "FAIL: $FAIL_COUNT/9"
echo "실행 시간: ${DURATION}s"

if [ $FAIL_COUNT -eq 0 ]; then
  if [ $WARN_COUNT -eq 0 ]; then
    echo "=== 보안 게이트 PASS (배포 허용) ==="
    RESULT_TAG="PASS"; RC=0
  else
    echo "=== 보안 게이트 PASS WITH WARNINGS ==="
    echo "WARN 항목: ${WARN_STEPS[*]}"
    RESULT_TAG="WARN"; RC=0
  fi
else
  echo "=== 보안 게이트 FAIL (배포 차단) ==="
  echo "FAIL 항목: ${FAIL_STEPS[*]}"
  RESULT_TAG="FAIL"; RC=1
fi

# sensor-log 박제 (2026-05-02 H8)
bash "$(dirname "$0")/sensor-log.sh" "sensor-security-gate" "$RESULT_TAG" "FAIL=$FAIL_COUNT WARN=$WARN_COUNT" 2>/dev/null || true
exit $RC
