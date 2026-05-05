#!/usr/bin/env bash
# sensor-fake-email-leak — @grimoire.app (실존하지 않는 가짜 도메인) 코드 박제 0건 강제
#
# 발동 조건:
# - pre-commit / pre-push (3 레포 모두)
# - 정기 회귀 (eval-runner)
#
# 정책 (EMAIL_INTEGRITY_PLAN.md §1-1 + §4):
# - 실 운영 코드 + 시드 + e2e + 마이그레이션에 @grimoire.app 박제 0건 강제
# - TODO.md / HANDOVER.md / *.md 회귀 사례 박제는 의도적 (의식적 회귀 추적용) — 검색 제외
# - claude-docs research/ 정본 + memory/ + reports/ 박제는 정본 의도 — 검색 제외
#
# Exit codes (sensor 패턴 정합):
# - 0 PASS — 코드 박제 0건
# - 1 WARN — 의도적 박제만 검출 (상위 라이센서 결정)
# - 2 FAIL — 운영 코드 박제 발견 (commit/push 차단)

# sensor-log 자동 박제 (트랙 1-A 보강 — exit code 자동 매핑: 0=PASS / 1=FAIL / 2=WARN)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set +e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 2

echo "── sensor-fake-email-leak (EMAIL-P0-1 회귀 차단) ──"

# 검색 대상 (운영 코드 영역)
SEARCH_PATHS=(
  "grimoire-server/src"
  "grimoire-server/scripts"
  "grimoire-server/prisma"
  "grimoire-web/src"
  "grimoire-web/e2e"
)

# 존재하는 경로만 추출
EXISTING_PATHS=()
for p in "${SEARCH_PATHS[@]}"; do
  if [ -d "$p" ]; then
    EXISTING_PATHS+=("$p")
  fi
done

if [ ${#EXISTING_PATHS[@]} -eq 0 ]; then
  echo "  ⚠ 검색 대상 경로 없음 — 단일 레포 컨텍스트일 가능성 (서브모듈 미존재)"
  exit 0
fi

# 검색 실행
HITS=$(grep -rn '@grimoire\.app' "${EXISTING_PATHS[@]}" 2>/dev/null)

if [ -z "$HITS" ]; then
  echo "  ✓ PASS — @grimoire.app 코드 박제 0건"
  exit 0
fi

# FAIL — 박제 검출
echo "  ✗ FAIL — @grimoire.app 박제 검출 (commit 차단)"
echo ""
echo "$HITS" | while IFS= read -r line; do
  echo "    $line"
done
echo ""
echo "  → 정리 정책: @grimoire.app → @example.com (RFC 2606 reserved)"
echo "  → 회귀 박제 (TODO.md / HANDOVER.md / research/) 는 검색 제외 영역"
echo "  → 정본: research/EMAIL_INTEGRITY_PLAN.md §2-1 EMAIL-P0-1"
exit 2
