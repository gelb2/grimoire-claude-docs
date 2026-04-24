#!/bin/bash
# 3환경 수동 배포 스크립트 — GitHub Actions 우회
set -euo pipefail

PROJECT_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire"
ACR="grimoireacr.azurecr.io"
RG="zenith-rg"

echo "=== [1/5] ACR 로그인 ==="
az acr login --name grimoireacr

echo "=== [2/5] Server Docker 빌드 (amd64) ==="
cd "$PROJECT_DIR/grimoire-server"
docker build --platform linux/amd64 -t $ACR/grimoire-server:latest .

echo "=== [3/5] Web Docker 빌드 (amd64 + NEXT_PUBLIC 변수) ==="
cd "$PROJECT_DIR/grimoire-web"
GOOGLE_ID=$(az containerapp show --name grimoire-web-prod --resource-group $RG --query "properties.template.containers[0].env[?name=='NEXT_PUBLIC_GOOGLE_CLIENT_ID'].value" -o tsv)
RECAPTCHA_KEY=$(az containerapp show --name grimoire-web-prod --resource-group $RG --query "properties.template.containers[0].env[?name=='NEXT_PUBLIC_RECAPTCHA_SITE_KEY'].value" -o tsv)
docker build --platform linux/amd64 \
  --build-arg NEXT_PUBLIC_GOOGLE_CLIENT_ID="$GOOGLE_ID" \
  --build-arg NEXT_PUBLIC_RECAPTCHA_SITE_KEY="$RECAPTCHA_KEY" \
  -t $ACR/grimoire-web:latest .

echo "=== [4/5] ACR 푸시 ==="
docker push $ACR/grimoire-server:latest &
docker push $ACR/grimoire-web:latest &
wait

echo "=== [5/5] 3환경 Container Apps 업데이트 ==="
for ENV in dev inhouse prod; do
  az containerapp update --name grimoire-server-$ENV --resource-group $RG --image $ACR/grimoire-server:latest -o none &
  az containerapp update --name grimoire-web-$ENV --resource-group $RG --image $ACR/grimoire-web:latest -o none &
done
wait

echo "=== Health Check ==="
sleep 15
for ENV_URL in "dev:dev-api.grimoire-book.com:dev.grimoire-book.com" "inhouse:inhouse-api.grimoire-book.com:inhouse.grimoire-book.com" "prod:api.grimoire-book.com:grimoire-book.com"; do
  IFS=':' read -r ENV API WEB <<< "$ENV_URL"
  S=$(curl -s -o /dev/null -w "%{http_code}" "https://$API/api/health")
  W=$(curl -s -o /dev/null -w "%{http_code}" -L "https://$WEB")
  echo "$ENV: server=$S web=$W"
done
echo "=== 배포 완료 ==="
