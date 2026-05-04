#!/bin/bash
# sensor-admin-credit-ui
# PAY-P0-3: 운영자 수동 크레딧 지급/차감 web UI 가드.
# Constitution P16 (결제 원자성) + P14 (BFF 프록시)와 함께 commit 직전 자동 차단.
# VCK 정본 (admin = neutral-* 영역, 작가 g-* 침범 0건) 검증.
#
# 검증 대상:
#   1. CreditsTab.tsx 별도 파일 존재
#   2. api.adminListAuthors 호출 (사용자 검색)
#   3. api.adminGrantCredits + api.adminDeductCredits 둘 다 박제
#   4. admin/page.tsx에 CreditsTab import 박제
#   5. Tab union 'credits' 등록 + 라우팅 분기
#   6. CreditsTab.test.tsx (또는 .spec.tsx) 신설
#   7. 작가 g-* 토큰 사용 0건 (VCK 시각 정본 보호)
#   8. 네이티브 confirm() 멀티콘펌 박제 (admin 11 tabs 정본)
#   9. sonner toast import (CommentsTab 신규 패턴 정합)
#  10. dangerouslySetInnerHTML 사용 0건 (XSS 차단)
#
# Exit codes:
#   0 = PASS / 1 = FAIL

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
WEB="$ROOT/grimoire-web"
TAB="$WEB/src/app/admin/tabs/CreditsTab.tsx"
TAB_TEST_TSX="$WEB/src/app/admin/tabs/CreditsTab.test.tsx"
TAB_SPEC_TSX="$WEB/src/app/admin/tabs/CreditsTab.spec.tsx"
PAGE="$WEB/src/app/admin/page.tsx"

PASS=0
FAIL=0

echo "=== sensor-admin-credit-ui ($(date '+%H:%M:%S')) ==="
echo ""

# 1. CreditsTab 별도 파일
if [ -f "$TAB" ]; then
  echo "  [PASS] CreditsTab.tsx 별도 파일 분리"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] CreditsTab.tsx 누락 — 인라인 정의(page.tsx) 잔존 가능성"
  FAIL=$((FAIL + 1))
fi

# 2. adminListAuthors 호출
if [ -f "$TAB" ] && grep -qE 'adminListAuthors' "$TAB" 2>/dev/null; then
  echo "  [PASS] api.adminListAuthors 호출 박제 (사용자 검색)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] adminListAuthors 호출 누락 — 사용자 검색 부재 (운영자 ID 추측 위험)"
  FAIL=$((FAIL + 1))
fi

# 3. adminGrantCredits + adminDeductCredits 둘 다
if [ -f "$TAB" ] && grep -qE 'adminGrantCredits' "$TAB" 2>/dev/null && grep -qE 'adminDeductCredits' "$TAB" 2>/dev/null; then
  echo "  [PASS] api.adminGrantCredits + adminDeductCredits 둘 다 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] grant/deduct API 호출 분기 누락"
  FAIL=$((FAIL + 1))
fi

# 4. admin/page.tsx CreditsTab import
if grep -qE "import.*CreditsTab.*from.*['\"]\\./tabs/CreditsTab['\"]" "$PAGE" 2>/dev/null; then
  echo "  [PASS] admin/page.tsx CreditsTab import 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] admin/page.tsx CreditsTab import 누락 — 미연결"
  FAIL=$((FAIL + 1))
fi

# 5. Tab union 'credits' + 라우팅
if grep -qE "'credits'" "$PAGE" 2>/dev/null && grep -qE "tab === 'credits'.*<CreditsTab" "$PAGE" 2>/dev/null; then
  echo "  [PASS] Tab union 'credits' 등록 + 라우팅 분기 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Tab union 'credits' 또는 라우팅 분기 누락"
  FAIL=$((FAIL + 1))
fi

# 6. spec 파일 (.test.tsx 또는 .spec.tsx)
if [ -f "$TAB_TEST_TSX" ] || [ -f "$TAB_SPEC_TSX" ]; then
  echo "  [PASS] CreditsTab spec 파일 박제"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] CreditsTab spec 파일 누락"
  FAIL=$((FAIL + 1))
fi

# 7. 작가 g-* 토큰 사용 0건 (VCK 시각 정본 보호)
if [ -f "$TAB" ]; then
  G_TOKEN_COUNT=$(grep -E 'g-bg|g-fg|g-accent|g-divider|g-font|g-surface|var\(--g-' "$TAB" 2>/dev/null | wc -l | tr -d ' \n')
  if [ "${G_TOKEN_COUNT:-0}" = "0" ]; then
    echo "  [PASS] 작가 g-* 토큰 사용 0건 (VCK 시각 정본 침범 차단)"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] 작가 g-* 토큰 ${G_TOKEN_COUNT}건 검출 — admin neutral-* 영역 침범"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [SKIP] CreditsTab 파일 부재 — g-* 검증 생략"
fi

# 8. 네이티브 confirm() 박제
if [ -f "$TAB" ] && grep -qE 'confirm\s*\(' "$TAB" 2>/dev/null; then
  echo "  [PASS] 네이티브 confirm() 멀티콘펌 박제 (admin 11 tabs 정본)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] confirm() 누락 — 휴먼 에러 차단 부재"
  FAIL=$((FAIL + 1))
fi

# 9. sonner toast import
if [ -f "$TAB" ] && grep -qE "from ['\"]sonner['\"]" "$TAB" 2>/dev/null; then
  echo "  [PASS] sonner toast import 박제 (CommentsTab 신규 패턴 정합)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] sonner import 누락 — 결과 표시 패턴 일탈"
  FAIL=$((FAIL + 1))
fi

# 10. dangerouslySetInnerHTML 사용 0건 (XSS 차단)
if [ -f "$TAB" ]; then
  XSS_COUNT=$(grep -E 'dangerouslySetInnerHTML' "$TAB" 2>/dev/null | wc -l | tr -d ' \n')
  if [ "${XSS_COUNT:-0}" = "0" ]; then
    echo "  [PASS] dangerouslySetInnerHTML 사용 0건 (XSS 차단)"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] dangerouslySetInnerHTML ${XSS_COUNT}건 검출 — XSS 위험"
    FAIL=$((FAIL + 1))
  fi
fi

echo ""
echo "─── 결과 ───"
echo "PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] FAIL — $FAIL 건 누락 (PAY-P0-3 회귀)"
  exit 1
fi

echo "[RESULT] PASS — 운영자 수동 크레딧 지급/차감 UI 패턴 모두 박제"
exit 0
