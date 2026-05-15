#!/usr/bin/env bash
# sensor-azure-env-secret — Container Apps env 평문 vs secretRef 정합 검증
#
# 발동 조건:
# - pre-deploy (main push 직전)
# - 정기 회귀 (eval-runner)
# - 사용자 명시 직접 호출
#
# 정본 (단일 진실):
# - reports/sprint-infra-1-mutation-guard-progress.md §4-4 + §5 AC-4
# - reports/HANDOVER-CRITICAL-2026-05-06.md §1-3 (보안 마이그레이션)
# - reports/HANDOVER-CRITICAL-2026-05-06-PP.md §1-1 (dev 153 ActivationFailed PUBLIC_API_BASE_URL 누락)
#
# 검증 영역:
# 1. 8 시크릿 매트릭스 모두 secretRef 박제 (DATABASE_URL/JWT/RECAPTCHA/ANTHROPIC/OPENAI/POLAR_ACCESS/POLAR_WEBHOOK/AZURE_STORAGE)
# 2. PUBLIC_API_BASE_URL 박제 (dev 153 회귀 차단 — 누락 시 startup fail)
# 3. POLAR_SERVER + POLAR_ORGANIZATION_ID + POLAR_PRODUCT_* env 박제 (Polar 결제 정합)
# 4. CORS_ORIGIN env 박제 (BFF 프록시 정합)
#
# 사용:
#   bash .claude/scripts/sensor-azure-env-secret.sh <APP_NAME>
#
# Exit codes:
# - 0 PASS
# - 1 WARN
# - 2 FAIL

trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set +e

APP="${1:-}"
RG="zenith-rg"

if [ -z "$APP" ]; then
  echo "  ⚠ APP_NAME 인자 필수"
  exit 1
fi

echo "── sensor-azure-env-secret (INFRA-1, target=$APP) ──"

PASS=0
FAIL=0
WARN=0

# 8 시크릿 매트릭스 (env name → secret name)
SECRET_KEYS=(
  "DATABASE_URL"
  "JWT_SECRET"
  "RECAPTCHA_SECRET_KEY"
  "ANTHROPIC_API_KEY"
  "OPENAI_API_KEY"
  "POLAR_ACCESS_TOKEN"
  "POLAR_WEBHOOK_SECRET"
  "AZURE_STORAGE_ACCOUNT_KEY"
)

# 1. 8 시크릿 secretRef 정합 검증
ENV_JSON=$(az containerapp show -n "$APP" -g "$RG" \
  --query "properties.template.containers[0].env" -o json 2>/dev/null)

if [ -z "$ENV_JSON" ] || [ "$ENV_JSON" = "null" ]; then
  echo "  ✗ Container App env 조회 실패"
  exit 2
fi

for KEY in "${SECRET_KEYS[@]}"; do
  HAS_SECRET_REF=$(echo "$ENV_JSON" | python3 -c "
import sys, json
envs = json.load(sys.stdin)
for e in envs:
    if e.get('name') == '$KEY':
        print('yes' if e.get('secretRef') else 'no')
        sys.exit(0)
print('missing')
" 2>/dev/null)

  case "$HAS_SECRET_REF" in
    yes)
      echo "  ✓ [secret] $KEY → secretRef"
      PASS=$((PASS+1))
      ;;
    no)
      echo "  ✗ [secret] $KEY 평문 박제 (Constitution P13 위반)"
      FAIL=$((FAIL+1))
      ;;
    missing)
      echo "  ⚠ [secret] $KEY 미박제 (env 누락)"
      WARN=$((WARN+1))
      ;;
  esac
done

# 2. PUBLIC_API_BASE_URL 박제 검증 (dev 153 회귀 차단)
PUBLIC_API_BASE_URL=$(echo "$ENV_JSON" | python3 -c "
import sys, json
envs = json.load(sys.stdin)
for e in envs:
    if e.get('name') == 'PUBLIC_API_BASE_URL':
        print(e.get('value', ''))
        sys.exit(0)
print('missing')
" 2>/dev/null)

if [ "$PUBLIC_API_BASE_URL" = "missing" ]; then
  echo "  ✗ [env] PUBLIC_API_BASE_URL 누락 (dev 153 ActivationFailed 회귀 위험)"
  FAIL=$((FAIL+1))
elif [ -n "$PUBLIC_API_BASE_URL" ]; then
  echo "  ✓ [env] PUBLIC_API_BASE_URL 박제 (value 존재)"
  PASS=$((PASS+1))
else
  echo "  ⚠ [env] PUBLIC_API_BASE_URL 빈 값"
  WARN=$((WARN+1))
fi

# 3. Polar 정합 env 검증
for KEY in "POLAR_SERVER" "POLAR_ORGANIZATION_ID" "POLAR_PRODUCT_BASIC" "POLAR_PRODUCT_POPULAR" "POLAR_PRODUCT_BEST"; do
  HAS=$(echo "$ENV_JSON" | python3 -c "
import sys, json
envs = json.load(sys.stdin)
print('yes' if any(e.get('name') == '$KEY' for e in envs) else 'no')
" 2>/dev/null)
  if [ "$HAS" = "yes" ]; then
    echo "  ✓ [env] $KEY 박제"
    PASS=$((PASS+1))
  else
    echo "  ⚠ [env] $KEY 누락 (Polar 결제 정합 부족)"
    WARN=$((WARN+1))
  fi
done

# 4. CORS_ORIGIN 박제
CORS=$(echo "$ENV_JSON" | python3 -c "
import sys, json
envs = json.load(sys.stdin)
print('yes' if any(e.get('name') == 'CORS_ORIGIN' for e in envs) else 'no')
" 2>/dev/null)
if [ "$CORS" = "yes" ]; then
  echo "  ✓ [env] CORS_ORIGIN 박제 (BFF 정합)"
  PASS=$((PASS+1))
else
  echo "  ⚠ [env] CORS_ORIGIN 누락"
  WARN=$((WARN+1))
fi

echo ""
echo "── 종합 ──"
echo "  PASS: $PASS / WARN: $WARN / FAIL: $FAIL"

if [ $FAIL -gt 0 ]; then
  echo "  ✗ FAIL — env/secret 정합 위반 (Constitution P13 또는 startup fail 위험)"
  echo "  → 정본: reports/sprint-infra-1-mutation-guard-progress.md §4-4 AC-4"
  echo "  → 회복: scripts/security/migrate-env-to-secretref.sh $APP"
  exit 2
fi

if [ $WARN -gt 0 ]; then
  echo "  ⚠ WARN — 부분 env 누락 (사용자 검토 권장)"
  exit 1
fi

echo "  ✓ PASS — env/secret 정합"
exit 0
