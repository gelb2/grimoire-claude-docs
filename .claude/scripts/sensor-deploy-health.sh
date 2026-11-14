#!/usr/bin/env bash
# sensor-deploy-health — Cloud Run 배포 후 health 자동 검증
#
# 2026-07-13 (H-2): Azure Container Apps(`az containerapp`) → GCP Cloud Run(`gcloud run`) 이관.
#   Azure는 2026-06-04 decommission(zenith-rg 삭제) 완료 → 기존 az 기반 센서는 무동작이었음.
#   현역 인프라 = GCP 단독 (project grimoire-491708 / region asia-northeast1).
#
# 발동 조건:
# - 배포(make deploy-*) 후 수동/자동 health 검증
# - infra-mutation-guard skill polling
# - 사용자 명시 직접 호출
#
# GCP 절대 규칙 (grimoire-server/CLAUDE.md §1): gcloud 측정 시 --project 명시 강제.
#   로컬 gcloud 전역 default가 다른 프로젝트(pr-letter-addr 등)일 수 있어 무지정 = 거짓 FAIL/PASS.
#   → 본 센서는 항상 --project=grimoire-491708 --region=asia-northeast1 명시.
#
# 검증 영역 (5건):
# 1. Service Ready condition == True
# 2. Serving revision Ready == True (revision-aware — startup 실패+직전 revision fallback 200 사고 검출)
# 3. Traffic 100% (serving revision 단일 라우팅)
# 4. curl public endpoint HTTP 2xx/3xx (+ 배포 image 보고)
# 5. startup time ≤ 120s (curl latency = cold start 포함 startup time / Cloudflare 524 가드)
#
# 사용:
#   bash .claude/scripts/sensor-deploy-health.sh <SERVICE>
#   SERVICE ∈ { grimoire-server-prod, grimoire-server-dev, grimoire-web-prod, grimoire-web-dev }
#
# Exit codes:
# - 0 PASS — 모두 정합
# - 1 WARN — 부분 정책 미준수 (Ready=Unknown/Deploying, traffic 도달 전 등 — 재검증 권장)
# - 2 FAIL — Ready=False 또는 Traffic!=100 또는 endpoint 응답 이상 (배포 실패)

# sensor-log 자동 박제
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set +e

APP="${1:-}"
GCP_PROJECT="grimoire-491708"
GCP_REGION="asia-northeast1"

if [ -z "$APP" ]; then
  echo "  ⚠ SERVICE 인자 필수 (예: bash sensor-deploy-health.sh grimoire-server-prod)"
  echo "     SERVICE ∈ { grimoire-server-prod, grimoire-server-dev, grimoire-web-prod, grimoire-web-dev }"
  exit 1
fi

# 서비스 → 공개 도메인 + health path 매핑 (docs/environments.md 정합)
case "$APP" in
  grimoire-server-prod) PUBLIC_URL="https://api.grimoire-book.com";     HEALTH_PATH="/api/health" ;;
  grimoire-server-dev)  PUBLIC_URL="https://dev-api.grimoire-book.com"; HEALTH_PATH="/api/health" ;;
  grimoire-web-prod)    PUBLIC_URL="https://grimoire-book.com";         HEALTH_PATH="/" ;;
  grimoire-web-dev)     PUBLIC_URL="https://dev.grimoire-book.com";     HEALTH_PATH="/" ;;
  *)
    echo "  ✗ 미지원 SERVICE: $APP (grimoire-{server,web}-{dev,prod} 만 지원)"
    exit 1 ;;
esac

echo "── sensor-deploy-health (GCP Cloud Run, target=$APP) ──"

# gcloud 존재 확인
if ! command -v gcloud >/dev/null 2>&1; then
  echo "  ✗ gcloud CLI 미설치 — 검증 불가"
  exit 2
fi

PASS=0
FAIL=0
WARN=0

# 1. 서비스 상태 조회 (--project/--region 명시 강제)
SVC_JSON=$(gcloud run services describe "$APP" \
  --region "$GCP_REGION" --project "$GCP_PROJECT" --format=json 2>/dev/null)

if [ -z "$SVC_JSON" ]; then
  echo "  ✗ 서비스 조회 실패 (gcloud run services describe $APP) — 미존재/미인증/프로젝트 불일치"
  echo "  → 확인: gcloud run services list --project $GCP_PROJECT --region $GCP_REGION"
  exit 2
fi

# 서비스 레벨 필드 파싱 (Ready / url / serving revision+traffic / latestReady)
SVC_FIELDS=$(printf '%s' "$SVC_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
st = d.get('status', {})
ready = ''; reason = ''
for c in st.get('conditions', []):
    if c.get('type') == 'Ready':
        ready = c.get('status', '') or ''
        reason = (c.get('reason', '') or (c.get('message', '') or ''))[:70]
        break
url = st.get('url', '') or (st.get('address', {}) or {}).get('url', '')
latest_ready = st.get('latestReadyRevisionName', '') or ''
best_pct = -1; best_rev = ''
for t in st.get('traffic', []) or []:
    p = t.get('percent', 0) or 0
    if p > best_pct:
        best_pct = p; best_rev = t.get('revisionName', '') or ''
serving = best_rev or latest_ready
print('SVC_READY=\"%s\"' % ready)
print('SVC_REASON=\"%s\"' % reason)
print('SVC_URL=\"%s\"' % url)
print('SERVING_REV=\"%s\"' % serving)
print('SERVING_PCT=\"%s\"' % (best_pct if best_pct >= 0 else 0))
print('LATEST_READY=\"%s\"' % latest_ready)
" 2>/dev/null)

eval "$SVC_FIELDS"
SVC_READY="${SVC_READY:-}"; SERVING_REV="${SERVING_REV:-}"; SERVING_PCT="${SERVING_PCT:-0}"

echo "  ◇ service: $APP (Ready=$SVC_READY serving_rev=$SERVING_REV traffic=$SERVING_PCT%)"
[ -n "${SVC_URL:-}" ] && echo "  ◇ run.app URL: $SVC_URL"

# ── [1/5] Service Ready condition ──
if [ "$SVC_READY" = "True" ]; then
  echo "  ✓ [1/5] Service Ready=True"
  PASS=$((PASS+1))
elif [ "$SVC_READY" = "Unknown" ] || [ -z "$SVC_READY" ]; then
  echo "  ⚠ [1/5] Service Ready=${SVC_READY:-none} (${SVC_REASON:-Deploying} — 안정화 대기, 재검증 권장)"
  WARN=$((WARN+1))
else
  echo "  ✗ [1/5] Service Ready=$SVC_READY (reason=$SVC_REASON) — 배포 실패"
  FAIL=$((FAIL+1))
fi

# ── [2/5] Serving revision Ready (revision-aware) + image ──
REV_IMAGE=""
if [ -n "$SERVING_REV" ]; then
  REV_JSON=$(gcloud run revisions describe "$SERVING_REV" \
    --region "$GCP_REGION" --project "$GCP_PROJECT" --format=json 2>/dev/null)
  if [ -n "$REV_JSON" ]; then
    REV_FIELDS=$(printf '%s' "$REV_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ready = ''
for c in d.get('status', {}).get('conditions', []):
    if c.get('type') == 'Ready':
        ready = c.get('status', '') or ''; break
img = ''
try:
    img = d['spec']['containers'][0]['image']
except Exception:
    img = ''
print('REV_READY=\"%s\"' % ready)
print('REV_IMAGE=\"%s\"' % img)
" 2>/dev/null)
    eval "$REV_FIELDS"
  fi
fi
REV_READY="${REV_READY:-}"

if [ "$REV_READY" = "True" ]; then
  echo "  ✓ [2/5] Serving revision Ready=True ($SERVING_REV)"
  PASS=$((PASS+1))
elif [ "$REV_READY" = "Unknown" ] || [ -z "$REV_READY" ]; then
  echo "  ⚠ [2/5] Serving revision Ready=${REV_READY:-unknown} — 안정화 대기/조회불가 (재검증 권장)"
  WARN=$((WARN+1))
else
  echo "  ✗ [2/5] Serving revision Ready=$REV_READY — startup 실패 (endpoint 200은 직전 revision fallback일 수 있음)"
  echo "  → 회복: rollback-revision skill / gcloud run services update-traffic $APP --to-revisions <healthy>=100"
  FAIL=$((FAIL+1))
fi
[ -n "$REV_IMAGE" ] && echo "  ◇ image: $REV_IMAGE"

# ── [3/5] Traffic 100% ──
if [ "$SERVING_PCT" = "100" ]; then
  echo "  ✓ [3/5] Traffic=100% ($SERVING_REV)"
  PASS=$((PASS+1))
else
  echo "  ✗ [3/5] Traffic=$SERVING_PCT% (100 아님) — split/canary 또는 배포 미완료"
  FAIL=$((FAIL+1))
fi

# ── [4/5] curl public endpoint ──
CURL_START=$(date +%s)
HTTP_STATUS=$(curl -sS --max-time 90 -o /dev/null -w "%{http_code}" "${PUBLIC_URL}${HEALTH_PATH}" 2>/dev/null)
CURL_END=$(date +%s)
CURL_TIME=$((CURL_END - CURL_START))

case "$HTTP_STATUS" in
  200|301|307|308)
    echo "  ✓ [4/5] curl ${PUBLIC_URL}${HEALTH_PATH} HTTP $HTTP_STATUS (${CURL_TIME}s)"
    PASS=$((PASS+1)) ;;
  *)
    echo "  ✗ [4/5] curl ${PUBLIC_URL}${HEALTH_PATH} HTTP $HTTP_STATUS (${CURL_TIME}s) — endpoint 응답 이상"
    FAIL=$((FAIL+1)) ;;
esac

# ── [5/5] startup time ≤ 120s (curl latency = cold start 포함 startup time / Cloudflare 524 가드) ──
if [ "$CURL_TIME" -le 120 ]; then
  echo "  ✓ [5/5] startup time (curl latency) ${CURL_TIME}s (≤120s)"
  PASS=$((PASS+1))
else
  echo "  ✗ [5/5] startup time (curl latency) ${CURL_TIME}s (>120s) — Cloudflare 524 위험"
  FAIL=$((FAIL+1))
fi

echo ""
echo "── 종합 ──"
echo "  PASS: $PASS / WARN: $WARN / FAIL: $FAIL"

if [ $FAIL -gt 0 ]; then
  echo "  ✗ FAIL — 배포 health 이상 검출 (rollback-revision skill 호출 권장)"
  echo "  → 회복: gcloud run services update-traffic $APP --region $GCP_REGION --project $GCP_PROJECT --to-revisions <last-healthy-revision>=100"
  exit 2
fi

if [ $WARN -gt 0 ]; then
  echo "  ⚠ WARN — 부분 정책 미준수 (Deploying/Unknown, 30~60s 후 재검증)"
  exit 1
fi

echo "  ✓ PASS — 배포 health 정합"
exit 0
