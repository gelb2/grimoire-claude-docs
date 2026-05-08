#!/usr/bin/env bash
# migrate-env-to-secretref.sh — Container Apps 평문 env → secretRef 마이그레이션 (멱등)
#
# Sprint SEC (sprint #10_7) — Constitution P13 위반 해소.
# 8 시크릿 (DATABASE_URL/JWT_SECRET/RECAPTCHA_SECRET_KEY/ANTHROPIC_API_KEY/OPENAI_API_KEY/
#         POLAR_ACCESS_TOKEN/POLAR_WEBHOOK_SECRET/AZURE_STORAGE_ACCOUNT_KEY)을
# Container Apps `secrets` 섹션 박제 + env section의 value → secretRef 교체.
#
# 멱등성:
# - 이미 secretRef인 env는 skip (아무 변화 없음)
# - secrets section에 동일 이름 박제 시 갱신만 (incremental)
#
# 사용:
#   bash scripts/security/migrate-env-to-secretref.sh <app-name>
#   예: bash scripts/security/migrate-env-to-secretref.sh grimoire-server-dev

set -euo pipefail

APP="${1:?Container App 이름 필수 (예: grimoire-server-dev)}"
RG="zenith-rg"

# 시크릿 매트릭스 (env name → secret name)
declare -a SECRET_KEYS=(
  "DATABASE_URL:database-url"
  "JWT_SECRET:jwt-secret"
  "RECAPTCHA_SECRET_KEY:recaptcha-secret-key"
  "ANTHROPIC_API_KEY:anthropic-api-key"
  "OPENAI_API_KEY:openai-api-key"
  "POLAR_ACCESS_TOKEN:polar-access-token"
  "POLAR_WEBHOOK_SECRET:polar-webhook-secret"
  "AZURE_STORAGE_ACCOUNT_KEY:azure-storage-account-key"
)

echo "── $APP env → secretRef 마이그레이션 시작 ──"

# 1. 평문 값 추출 (transcript 마스킹 — 명령 출력 안 보이게)
# bash 3.2 호환 (macOS 기본) — associative array 대신 임시 파일 사용
SKIPPED=0
ALREADY_SECRETREF=0
PENDING=0
TMP_VALUES=$(mktemp)
trap 'rm -f "$TMP_VALUES"' EXIT

for entry in "${SECRET_KEYS[@]}"; do
  ENV_NAME="${entry%%:*}"
  SECRET_NAME="${entry##*:}"

  # 현재 정의 형태 조회
  current=$(az containerapp show -n "$APP" -g "$RG" \
    --query "properties.template.containers[0].env[?name=='$ENV_NAME'] | [0]" \
    -o json 2>/dev/null || echo "null")

  if [ "$current" = "null" ] || [ -z "$current" ]; then
    echo "  ↷ skip $ENV_NAME — env 박제 0건 (이 앱에 없음)"
    SKIPPED=$((SKIPPED+1))
    continue
  fi

  has_secretref=$(echo "$current" | python3 -c "import json,sys; d=json.load(sys.stdin); print('true' if d.get('secretRef') else 'false')")
  if [ "$has_secretref" = "true" ]; then
    echo "  ✓ already $ENV_NAME — secretRef 박제됨 (skip)"
    ALREADY_SECRETREF=$((ALREADY_SECRETREF+1))
    continue
  fi

  # 평문 value 추출 (마스킹 — 출력 0)
  val=$(az containerapp show -n "$APP" -g "$RG" \
    --query "properties.template.containers[0].env[?name=='$ENV_NAME'].value | [0]" \
    -o tsv 2>/dev/null || echo "")
  if [ -z "$val" ]; then
    echo "  ⚠ skip $ENV_NAME — value 추출 실패"
    SKIPPED=$((SKIPPED+1))
    continue
  fi

  # tab 구분 (값에 tab이 들어가면 안 됨 — 정상 시크릿은 tab 미포함)
  printf '%s\t%s\t%s\n' "$ENV_NAME" "$SECRET_NAME" "$val" >> "$TMP_VALUES"
  PENDING=$((PENDING+1))
  echo "  → pending $ENV_NAME → secretref:$SECRET_NAME"
done

if [ "$PENDING" -eq 0 ]; then
  echo ""
  echo "✓ 마이그레이션 대상 0건 (already=$ALREADY_SECRETREF / skip=$SKIPPED)"
  exit 0
fi

# 2. secrets section 박제 (한 번에 — incremental)
echo ""
echo "── 단계 2: secrets section 박제 (PENDING=$PENDING) ──"
SECRET_ARGS=()
while IFS=$'\t' read -r ENV_NAME SECRET_NAME VAL; do
  SECRET_ARGS+=("$SECRET_NAME=$VAL")
done < "$TMP_VALUES"
az containerapp secret set -n "$APP" -g "$RG" --secrets "${SECRET_ARGS[@]}" -o none
echo "  ✓ secrets set 완료"

# 3. env section을 secretRef로 교체
echo ""
echo "── 단계 3: env section secretRef 교체 ──"
ENV_ARGS=()
while IFS=$'\t' read -r ENV_NAME SECRET_NAME VAL; do
  ENV_ARGS+=("$ENV_NAME=secretref:$SECRET_NAME")
done < "$TMP_VALUES"
az containerapp update -n "$APP" -g "$RG" --set-env-vars "${ENV_ARGS[@]}" -o none
echo "  ✓ env update 완료 (새 revision 생성)"

echo ""
echo "── 검증 ──"
az containerapp show -n "$APP" -g "$RG" \
  --query "properties.template.containers[0].env[?name=='DATABASE_URL' || name=='JWT_SECRET' || name=='POLAR_ACCESS_TOKEN'].{name:name, hasValue:value!=null, hasSecretRef:secretRef!=null}" \
  -o table
echo ""
echo "✓ $APP 마이그레이션 완료 — pending=$PENDING / already=$ALREADY_SECRETREF / skip=$SKIPPED"
