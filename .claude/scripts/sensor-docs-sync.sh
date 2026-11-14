#!/bin/bash
# sensor-docs-sync.sh — server/web docs 동기화 검증

# sensor-log 자동 박제 (트랙 1-C 보강 — exit code 자동 매핑: 0=PASS / 1=FAIL / 2=WARN)
trap '_rc=$?; bash "$(dirname "$0")/sensor-log.sh" "$(basename "$0" .sh)" "$_rc" "" 2>/dev/null || true' EXIT

set -euo pipefail
SERVER="/Users/sokol/Git/ProjectGrimoire/grimoire-server"
WEB="/Users/sokol/Git/ProjectGrimoire/grimoire-web"
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
