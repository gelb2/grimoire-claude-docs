#!/bin/bash
# 수동 운영 배포 스크립트 — GitHub Actions Billing 실패 시 우회
set -euo pipefail

PROJECT_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire"
ACR="grimoireacr.azurecr.io"
RG="zenith-rg"

echo "=== [1/6] ACR 로그인 ==="
az acr login --name grimoireacr

echo "=== [2/6] Server Docker 빌드 (amd64) ==="
cd "$PROJECT_DIR/grimoire-server"
docker build --platform linux/amd64 -t $ACR/grimoire-server:latest .

echo "=== [3/6] Web Docker 빌드 (amd64 + NEXT_PUBLIC 변수) ==="
cd "$PROJECT_DIR/grimoire-web"
GOOGLE_ID=$(az containerapp show --name grimoire-web-prod --resource-group $RG --query "properties.template.containers[0].env[?name=='NEXT_PUBLIC_GOOGLE_CLIENT_ID'].value" -o tsv)
RECAPTCHA_KEY=$(az containerapp show --name grimoire-web-prod --resource-group $RG --query "properties.template.containers[0].env[?name=='NEXT_PUBLIC_RECAPTCHA_SITE_KEY'].value" -o tsv)
docker build --platform linux/amd64 \
  --build-arg NEXT_PUBLIC_GOOGLE_CLIENT_ID="$GOOGLE_ID" \
  --build-arg NEXT_PUBLIC_RECAPTCHA_SITE_KEY="$RECAPTCHA_KEY" \
  -t $ACR/grimoire-web:latest .

echo "=== [4/6] ACR 푸시 ==="
docker push $ACR/grimoire-server:latest
docker push $ACR/grimoire-web:latest

echo "=== [5/6] Container Apps 업데이트 ==="
az containerapp update --name grimoire-server-prod --resource-group $RG --image $ACR/grimoire-server:latest -o none
az containerapp update --name grimoire-web-prod --resource-group $RG --image $ACR/grimoire-web:latest -o none

echo "=== [6/6] Health Check ==="
sleep 10
SERVER_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://api.grimoire-book.com/api/health)
WEB_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L https://grimoire-book.com)
echo "server: $SERVER_CODE"
echo "web: $WEB_CODE"

if [ "$SERVER_CODE" = "200" ] && [ "$WEB_CODE" = "200" ]; then
  echo "=== 배포 성공 ==="
else
  echo "=== 배포 실패 — 확인 필요 ==="
  exit 1
fi
