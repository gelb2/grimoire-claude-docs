#!/usr/bin/env bash
# sensor-deploy-drift.sh — server/web develop ↔ main ↔ Azure 배포 동기화 검증
#
# 동기 (HARNESS §10 Phase 4):
#   - 배포 후 develop만 push되고 main 머지/배포 안 된 경우 ↑
#   - server develop HEAD ≠ Container App 현재 image SHA → 운영 회귀 위험
#   - 본 sensor는 로컬에서 검증 가능한 부분만 검사 (운영 image 조회는 권한 차단으로 사용자 직접 명령으로 분리)
#
# 검사 항목 (로컬 + curl 가능):
#   1. server/web 각 레포 develop HEAD vs origin/develop (push 누락)
#   2. server/web develop ahead/behind main (배포 대기 커밋 수)
#   3. dev/prod health endpoint 응답 (운영 살아있는지)
#
# 운영 image SHA 비교 (사용자 직접 실행 — 권한 차단):
#   본 sensor는 표기만 하고 실측은 안 함. 사용자가 다음 명령으로 직접:
#     az containerapp show --name grimoire-server-prod --resource-group zenith-rg --query properties.template.containers[0].image -o tsv
#   결과를 git log --oneline -10 main 과 비교
#
# 사용:
#   sensor-deploy-drift.sh         # 전체 검사
#   sensor-deploy-drift.sh --quiet # PASS 시 출력 없음
#   sensor-deploy-drift.sh --strict # FAIL 시 exit 1

set -u

SERVER="/Users/sokol/Git/ProjectGrimoire/grimoire-server"
WEB="/Users/sokol/Git/ProjectGrimoire/grimoire-web"
LOG_DIR="/Users/sokol/Git/ProjectGrimoire/.claude/state"
OUTPUT_FILE="$LOG_DIR/deploy-drift.jsonl"

mkdir -p "$LOG_DIR"

QUIET=0
STRICT=0
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --strict) STRICT=1 ;;
  esac
done

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
declare -a FINDINGS=()

check() {
  local name="$1" result="$2" detail="$3"
  case "$result" in
    PASS) PASS_COUNT=$((PASS_COUNT+1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT+1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT+1)) ;;
  esac
  FINDINGS+=("[$result] $name — $detail")
}

[ "$QUIET" -eq 0 ] && echo "=== sensor-deploy-drift ($(date +'%H:%M:%S')) ==="

check_repo_drift() {
  local label="$1" repo="$2"
  if [ ! -d "$repo/.git" ]; then
    check "$label .git" "WARN" "디렉토리 없음 (skip)"
    return
  fi
  cd "$repo"

  git fetch origin develop main 2>/dev/null

  local local_dev=$(git rev-parse develop 2>/dev/null || echo "no-dev")
  local origin_dev=$(git rev-parse origin/develop 2>/dev/null || echo "no-dev")
  local origin_main=$(git rev-parse origin/main 2>/dev/null || echo "no-main")

  # 1. develop HEAD vs origin/develop
  if [ "$local_dev" = "no-dev" ] || [ "$origin_dev" = "no-dev" ]; then
    check "$label develop 브랜치" "WARN" "develop 또는 origin/develop 없음"
  else
    local ahead=$(git rev-list --count "$origin_dev".."$local_dev" 2>/dev/null || echo 0)
    local behind=$(git rev-list --count "$local_dev".."$origin_dev" 2>/dev/null || echo 0)
    if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
      check "$label develop ↔ origin/develop" "PASS" "동기화 (HEAD ${local_dev:0:7})"
    else
      check "$label develop ↔ origin/develop" "WARN" "ahead $ahead / behind $behind — push/pull 필요"
    fi
  fi

  # 2. develop vs main (배포 대기 커밋 수)
  if [ "$origin_dev" != "no-dev" ] && [ "$origin_main" != "no-main" ]; then
    local ahead_main=$(git rev-list --count "$origin_main".."$origin_dev" 2>/dev/null || echo 0)
    if [ "$ahead_main" -eq 0 ]; then
      check "$label develop ahead main" "PASS" "0건 (배포 대기 없음)"
    elif [ "$ahead_main" -le 5 ]; then
      check "$label develop ahead main" "PASS" "$ahead_main 건 (배포 대기, 정상 범위)"
    else
      check "$label develop ahead main" "WARN" "$ahead_main 건 (배포 대기 ↑, prod 배포 권장)"
    fi
  fi
}

check_repo_drift "server" "$SERVER"
check_repo_drift "web" "$WEB"

# 3. dev/prod health endpoint
# Container Apps scale-to-zero 환경에서 cold start 시 응답이 ~30초 걸릴 수 있음 (실측 기준).
# max-time 60s + 시간대별 임계값 차등화:
#   - <2s: PASS (warm pool 정상 응답)
#   - 2~10s: PASS (정상 범위, 일반 응답)
#   - 10~35s: WARN (cold start 의심, dev 환경에서는 정상)
#   - 35~60s: WARN (cold start ↑, prod이면 검토)
#   - >60s 또는 응답 없음: FAIL (서버 다운 가능성)
# 307 리다이렉트도 정상 응답으로 인정 (web 루트 → /explore)
check_health() {
  local label="$1" url="$2"
  local response code time
  response=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" --max-time 60 "$url" 2>/dev/null)
  code=$(echo "$response" | awk '{print $1}')
  time=$(echo "$response" | awk '{print $2}')
  if [ "$code" = "200" ] || [ "$code" = "307" ] || [ "$code" = "308" ]; then
    local time_int=$(awk -v t="$time" 'BEGIN{print int(t)}')
    if [ "$time_int" -lt 2 ]; then
      check "$label health" "PASS" "HTTP $code (${time}s, warm)"
    elif [ "$time_int" -lt 10 ]; then
      check "$label health" "PASS" "HTTP $code (${time}s, 정상 응답)"
    elif [ "$time_int" -lt 35 ]; then
      check "$label health" "WARN" "HTTP $code (${time}s, cold start 의심)"
    else
      check "$label health" "WARN" "HTTP $code (${time}s, 매우 느림 — prod이면 검토)"
    fi
  elif [ -z "$code" ] || [ "$code" = "000" ]; then
    check "$label health" "FAIL" "응답 없음 (60s 타임아웃 — 서버 다운 가능성)"
  else
    check "$label health" "FAIL" "HTTP $code (${time}s)"
  fi
}

check_health "dev-api" "https://dev-api.grimoire-book.com/api/health"
check_health "prod-api" "https://api.grimoire-book.com/api/health"

# 4. 운영 image SHA 비교 — 사용자 직접 명령 안내
check "운영 image SHA 비교 (수동)" "WARN" "권한 차단으로 메인 자동 측정 불가. 사용자 직접 검증:
    az containerapp show --name grimoire-server-prod --resource-group zenith-rg --query properties.template.containers[0].image -o tsv
    cd grimoire-server && git log --oneline main -5
  → image tag의 prod-{SHA} 값과 main 최근 커밋 SHA 일치 확인"

# 결과
if [ "$QUIET" -eq 0 ]; then
  echo ""
  echo "─── 결과 ───"
  printf '%s\n' "${FINDINGS[@]}"
  echo ""
  echo "PASS: $PASS_COUNT / FAIL: $FAIL_COUNT / WARN: $WARN_COUNT"
fi

# JSONL 적재
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RESULT_STATUS="PASS"
[ "$WARN_COUNT" -gt 0 ] && RESULT_STATUS="WARN"
[ "$FAIL_COUNT" -gt 0 ] && RESULT_STATUS="FAIL"
printf '{"ts":"%s","pass":%s,"warn":%s,"fail":%s,"status":"%s"}\n' \
  "$TS" "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT" "$RESULT_STATUS" >> "$OUTPUT_FILE"

# sensor-log 적재
SENSOR_LOG="/Users/sokol/Git/ProjectGrimoire/.claude/scripts/sensor-log.sh"
if [ -x "$SENSOR_LOG" ]; then
  RC=0
  [ "$FAIL_COUNT" -gt 0 ] && RC=1
  [ "$WARN_COUNT" -gt 0 ] && [ "$FAIL_COUNT" -eq 0 ] && RC=2
  bash "$SENSOR_LOG" "sensor-deploy-drift" "$RC" "PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT" 2>/dev/null || true
fi

# Exit
if [ "$FAIL_COUNT" -gt 0 ]; then
  if [ "$STRICT" -eq 1 ]; then
    [ "$QUIET" -eq 0 ] && echo "[RESULT] FAIL (strict) — 배포 drift 즉시 검토"
    exit 1
  fi
  [ "$QUIET" -eq 0 ] && echo "[RESULT] FAIL — 즉시 검토 (strict 미사용)"
  exit 0
elif [ "$WARN_COUNT" -gt 0 ]; then
  [ "$QUIET" -eq 0 ] && echo "[RESULT] WARN — $WARN_COUNT 건 검토"
  exit 2
fi

[ "$QUIET" -eq 0 ] && echo "[RESULT] PASS — 배포 drift 없음"
exit 0
