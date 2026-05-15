#!/usr/bin/env bash
# sensor-deploy-health — Container Apps 배포 후 health 자동 검증
#
# 발동 조건:
# - pre-push (main 브랜치 직전 — server / web)
# - infra-mutation-guard skill Step 3 polling 호출
# - 정기 회귀 (eval-runner)
# - 사용자 명시 직접 호출
#
# 정본 (단일 진실):
# - reports/sprint-infra-1-mutation-guard-progress.md §4-3 + §5 AC-3
# - .claude/shared-contracts.md §21 InfraMutationGuard
#
# 검증 영역 (5건):
# 1. 신규 revision Healthy 검증
# 2. Traffic 100% 정합
# 3. curl public endpoint HTTP 200
# 4. replicas ≥1 또는 ScaledToZero (정상)
# 5. startup time ≤120s
#
# 사용:
#   bash .claude/scripts/sensor-deploy-health.sh <APP_NAME>
#   예: bash .claude/scripts/sensor-deploy-health.sh grimoire-server-prod
#
# Exit codes:
# - 0 PASS — 모두 정합
# - 1 WARN — 부분 정책 미준수 (예: ScaledToZero, 첫 traffic 도달 전)
# - 2 FAIL — Healthy != true 또는 Traffic != 100 (배포 실패)

# sensor-log 자동 박제
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set +e

APP="${1:-}"
RG="zenith-rg"

if [ -z "$APP" ]; then
  echo "  ⚠ APP_NAME 인자 필수 (예: bash sensor-deploy-health.sh grimoire-server-prod)"
  exit 1
fi

echo "── sensor-deploy-health (INFRA-1, target=$APP) ──"

PASS=0
FAIL=0
WARN=0

# 1. revision 상태 조회
REVISION_INFO=$(az containerapp revision list -n "$APP" -g "$RG" \
  --query "[?properties.trafficWeight==\`100\`] | [0].{name:name, health:properties.healthState, running:properties.runningState, traffic:properties.trafficWeight, created:properties.createdTime}" \
  -o json 2>/dev/null)

if [ -z "$REVISION_INFO" ] || [ "$REVISION_INFO" = "null" ]; then
  echo "  ✗ Active revision (Traffic 100%) 미존재 — Container Apps 상태 이상"
  exit 2
fi

REV_NAME=$(echo "$REVISION_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null)
REV_HEALTH=$(echo "$REVISION_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin).get('health',''))" 2>/dev/null)
REV_RUNNING=$(echo "$REVISION_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin).get('running',''))" 2>/dev/null)
REV_TRAFFIC=$(echo "$REVISION_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin).get('traffic',''))" 2>/dev/null)

echo "  ◇ revision: $REV_NAME (health=$REV_HEALTH running=$REV_RUNNING traffic=$REV_TRAFFIC%)"

# 2. HealthState=Healthy 검증
if [ "$REV_HEALTH" = "Healthy" ]; then
  echo "  ✓ [1/5] HealthState=Healthy"
  PASS=$((PASS+1))
elif [ "$REV_HEALTH" = "None" ]; then
  echo "  ⚠ [1/5] HealthState=None (Activating 가능, 60s 후 재검증 권장)"
  WARN=$((WARN+1))
else
  echo "  ✗ [1/5] HealthState=$REV_HEALTH (Unhealthy/Failed) — 배포 실패"
  FAIL=$((FAIL+1))
fi

# 3. Traffic 100% 정합
if [ "$REV_TRAFFIC" = "100" ]; then
  echo "  ✓ [2/5] Traffic=100%"
  PASS=$((PASS+1))
else
  echo "  ✗ [2/5] Traffic=$REV_TRAFFIC% (100 아님) — 배포 미완료"
  FAIL=$((FAIL+1))
fi

# 4. RunningState 분기
case "$REV_RUNNING" in
  RunningAtMaxScale|Running)
    echo "  ✓ [3/5] RunningState=$REV_RUNNING"
    PASS=$((PASS+1))
    ;;
  ScaledToZero)
    echo "  ⚠ [3/5] RunningState=ScaledToZero (idle 정상, 첫 트래픽 시 cold start)"
    WARN=$((WARN+1))
    ;;
  Activating)
    echo "  ⚠ [3/5] RunningState=Activating (시작 중, 30~60s 대기)"
    WARN=$((WARN+1))
    ;;
  *)
    echo "  ✗ [3/5] RunningState=$REV_RUNNING (Failed/Deprovisioning) — 배포 실패"
    FAIL=$((FAIL+1))
    ;;
esac

# 5. curl public endpoint 검증
APP_URL="https://${APP/grimoire-server/api.grimoire-book.com}"
APP_URL="${APP_URL/-prod/}"
APP_URL="${APP_URL/-dev/}"
# 실제 매핑: grimoire-server-prod → api.grimoire-book.com / grimoire-server-dev → dev-api.grimoire-book.com
case "$APP" in
  grimoire-server-prod) APP_URL="https://api.grimoire-book.com" ;;
  grimoire-server-dev)  APP_URL="https://dev-api.grimoire-book.com" ;;
  grimoire-web-prod)    APP_URL="https://grimoire-book.com" ;;
  grimoire-web-dev)     APP_URL="https://dev.grimoire-book.com" ;;
esac

CURL_PATH="/api/payments/products"
case "$APP" in
  grimoire-web-*) CURL_PATH="/" ;;
esac

CURL_START=$(date +%s)
HTTP_STATUS=$(curl -sS --max-time 90 -o /dev/null -w "%{http_code}" "${APP_URL}${CURL_PATH}" 2>/dev/null)
CURL_END=$(date +%s)
CURL_TIME=$((CURL_END - CURL_START))

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "307" ]; then
  echo "  ✓ [4/5] curl ${APP_URL}${CURL_PATH} HTTP $HTTP_STATUS (${CURL_TIME}s)"
  PASS=$((PASS+1))
else
  echo "  ✗ [4/5] curl ${APP_URL}${CURL_PATH} HTTP $HTTP_STATUS (${CURL_TIME}s) — endpoint 응답 이상"
  FAIL=$((FAIL+1))
fi

# 6. startup time ≤120s 검증
if [ "$CURL_TIME" -le 120 ]; then
  echo "  ✓ [5/5] startup time ${CURL_TIME}s (≤120s)"
  PASS=$((PASS+1))
else
  echo "  ✗ [5/5] startup time ${CURL_TIME}s (>120s) — Cloudflare 524 위험"
  FAIL=$((FAIL+1))
fi

echo ""
echo "── 종합 ──"
echo "  PASS: $PASS / WARN: $WARN / FAIL: $FAIL"

if [ $FAIL -gt 0 ]; then
  echo "  ✗ FAIL — 배포 health 이상 검출 (rollback-revision skill 호출 권장)"
  echo "  → 정본: reports/sprint-infra-1-mutation-guard-progress.md §4-3 AC-3"
  echo "  → 회복: az containerapp update -n $APP -g $RG --image <last-healthy-image>"
  exit 2
fi

if [ $WARN -gt 0 ]; then
  echo "  ⚠ WARN — 부분 정책 미준수 (Activating/ScaledToZero, 60s 후 재검증)"
  exit 1
fi

echo "  ✓ PASS — 배포 health 정합"
exit 0
