#!/bin/bash
# sensor-docs-sync.sh — server/web docs 동기화 검증
set -euo pipefail
SERVER="/Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server"
WEB="/Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web"
FAIL=0

echo "=== docs 동기화 검증 ==="
for doc in api-contract.md data-model.md glossary.md environments.md ai-analysis-spec.md TERMS_OF_SERVICE.md PRIVACY_POLICY.md; do
  if ! diff -q "$SERVER/docs/$doc" "$WEB/docs/$doc" >/dev/null 2>&1; then
    echo "FAIL: $doc 불일치"
    FAIL=1
  else
    echo "PASS: $doc"
  fi
done

# web 정본 docs
for doc in theme-spec.md design-tokens.md; do
  if ! diff -q "$WEB/docs/$doc" "$SERVER/docs/$doc" >/dev/null 2>&1; then
    echo "FAIL: $doc 불일치"
    FAIL=1
  else
    echo "PASS: $doc"
  fi
done

if [ $FAIL -eq 1 ]; then
  echo "=== docs 동기화 FAIL ==="
  exit 1
fi
echo "=== docs 동기화 PASS ==="
