#!/usr/bin/env bash
# sensor-secret-leak.sh — git tracked 파일에서 평문 시크릿 누출 감지
#
# 2026-04-25 신설. 동기:
#   - 같은 날 보안 감사에서 PRIVATE repo에 평문 5종이 push되어 있었음
#     (REMOVED_CREDENTIAL_010 / REMOVED_CREDENTIAL_014 / REMOVED_CREDENTIAL_013 / REMOVED_CREDENTIAL_012
#      / grimoire-dev-secret JWT fallback)
#   - sensor-security-gate.sh 8항목엔 시크릿 검사가 없어 강력 grep으로 우회
#   - 본 sensor를 §9로 추가하여 재발 방지
#
# 검사 범위
#   - 3 레포 git tracked 파일만 (working tree 미커밋은 제외)
#   - .env, .env.example, docs/environments.md, ACCOUNTS.md는 의도된 위치 (WARN)
#   - 그 외 매칭 시 FAIL
#
# Exit codes
#   0  PASS
#   1  FAIL (FAIL 매칭 1건 이상)
#   2  WARN only (의도된 위치에만 매칭, 정상)

# sensor-log 자동 박제 (트랙 1-C 보강 — exit code 자동 매핑: 0=PASS / 1=FAIL / 2=WARN)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -u

PROJECT_ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
REPOS=(
  "$PROJECT_ROOT"
  "$PROJECT_ROOT/grimoire-server"
  "$PROJECT_ROOT/grimoire-web"
)

# 의도된 시크릿 보관 위치 (WARN으로 처리, FAIL 안 함)
INTENDED_PATHS_REGEX='^(\.env(\..+)?|\.env\.example|docs/environments\.md|grimoire-(server|web)/docs/environments\.md|ACCOUNTS\.md|grimoire-(server|web)/\.env\.example)$'

# 패턴 모음 — 라이브 시크릿 prefix
LIVE_PATTERNS=(
  'sk-ant-api03-[a-zA-Z0-9_-]{20,}'
  'sk-proj-[a-zA-Z0-9_-]{20,}'
  'AKIA[A-Z0-9]{16}'
  'ghp_[a-zA-Z0-9]{36}'
  'github_pat_[a-zA-Z0-9_]{40,}'
  'xoxb-[a-zA-Z0-9-]{30,}'
  'polar_oat_[a-zA-Z0-9]{30,}'
  'polar_pak_[a-zA-Z0-9]{20,}'
  'polar_whs_[a-zA-Z0-9]{30,}'
  'AIza[a-zA-Z0-9_-]{35}'
  'sk_live_[a-zA-Z0-9]{20,}'
  'pk_live_[a-zA-Z0-9]{20,}'
)

# 알려진 약한 default 값 (평문 검사)
# - REMOVED_CREDENTIAL_011: 로컬 docker-compose 의도 (외부 영향 없음 — 패턴 제외)
# - masked2026: db-sync 마스킹 hash 주석/설명용 (외부 영향 없음 — 패턴 제외)
# - test1234: 과거 dev 테스트 비번 (회전 후 잔재 정리)
WEAK_LITERALS=(
  'REMOVED_CREDENTIAL_010'
  'grimoire-dev-secret'
  'REMOVED_CREDENTIAL_014'
  'REMOVED_CREDENTIAL_013'
  'REMOVED_CREDENTIAL_012'
  'test1234'
)

FAIL_COUNT=0
WARN_COUNT=0
declare -a FAIL_HITS=()
declare -a WARN_HITS=()

scan_repo() {
  local repo="$1"
  local repo_name
  repo_name=$(basename "$repo")
  [ ! -d "$repo/.git" ] && return 0

  pushd "$repo" >/dev/null

  # git repo 유효성 확인 (tracked 없으면 skip)
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { popd >/dev/null; return 0; }

  # 2026-07-13 (H-1 이중실행 봉합): xargs -I{} grep {} 안티패턴 제거.
  #   기존: tracked 파일 수천 개 × 패턴 18종 × 3레포 = grep 프로세스 수만 개 spawn → 28.8s.
  #   현행: `git grep` = tracked working-tree 파일 배치 검색 (동일 파일집합·동일 ERE/-F 시맨틱) → <1s.
  #   -I = binary skip (시크릿은 텍스트), -e = 패턴을 옵션으로 오인 방지.
  #   FAIL/WARN 분류(INTENDED_PATHS_REGEX)·head 캡·자기제외 전부 보존.

  # 1) Live secret prefix
  for pattern in "${LIVE_PATTERNS[@]}"; do
    while IFS=: read -r file line; do
      [ -z "$file" ] && continue
      if echo "$file" | grep -qE "$INTENDED_PATHS_REGEX"; then
        WARN_COUNT=$((WARN_COUNT + 1))
        WARN_HITS+=("[$repo_name] $file:$line  (live: $pattern)")
      else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAIL_HITS+=("[$repo_name] $file:$line  (live: $pattern)")
      fi
    done < <(git grep -I -nE -e "$pattern" 2>/dev/null | head -100 | awk -F: '{print $1":"$2}')
  done

  # 2) Weak literals
  for literal in "${WEAK_LITERALS[@]}"; do
    while IFS=: read -r file line; do
      [ -z "$file" ] && continue
      # sensor-secret-leak.sh 자기 자신은 제외 (정의된 패턴이므로 자기 인용)
      [[ "$file" == *"sensor-secret-leak.sh"* ]] && continue
      if echo "$file" | grep -qE "$INTENDED_PATHS_REGEX"; then
        WARN_COUNT=$((WARN_COUNT + 1))
        WARN_HITS+=("[$repo_name] $file:$line  (weak: $literal)")
      else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAIL_HITS+=("[$repo_name] $file:$line  (weak: $literal)")
      fi
    done < <(git grep -I -nF -e "$literal" 2>/dev/null | head -100 | awk -F: '{print $1":"$2}')
  done

  popd >/dev/null
}

echo "=== sensor-secret-leak.sh ==="
echo "검사 시작: $(date +'%Y-%m-%d %H:%M:%S')"
echo ""

for repo in "${REPOS[@]}"; do
  echo "[검사] $repo"
  scan_repo "$repo"
done

echo ""
echo "=== 결과 ==="
echo "FAIL (위반): $FAIL_COUNT 건"
echo "WARN (의도된 위치): $WARN_COUNT 건"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo ""
  echo "─── FAIL 상세 (FAIL 1건이라도 있으면 exit 1) ───"
  printf '%s\n' "${FAIL_HITS[@]}" | head -30
fi

if [ "$WARN_COUNT" -gt 0 ] && [ "$FAIL_COUNT" -eq 0 ]; then
  echo ""
  echo "─── WARN 상세 (의도된 vault — 정상) ───"
  printf '%s\n' "${WARN_HITS[@]}" | head -10
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo ""
  echo "[RESULT] FAIL — git tracked 파일에서 평문 시크릿 발견. 즉시 회수 + history rewrite 검토."
  exit 1
elif [ "$WARN_COUNT" -gt 0 ]; then
  echo "[RESULT] WARN — 의도된 vault에만 매칭됨. 정상."
  exit 2
else
  echo "[RESULT] PASS — 모든 git tracked 파일 클린."
  exit 0
fi
