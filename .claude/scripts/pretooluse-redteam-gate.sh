#!/bin/bash
# pretooluse-redteam-gate.sh — Bash 위험 명령 직전 레드팀 검증 게이트
#
# 사용자 명시 (2026-05-06 묶음 NN):
# > "커밋, 푸시 내 개입 없이 진행
# >  커밋: 레드팀 안 거친 커밋은 무조건 리젝
# >  푸시: 레드팀 안 거친 커밋이 있으면 무조건 리젝
# >  인프라 변경 시크릿 변경 리비전 롤백 엔피엠 배포 모두 레드팀 안 거치면 리젝
# >  리젝이 걸리면, 하려던 절차 처음부터 다시 진행, 적절한 에이전트에 위임 및 장애 리포트에 박제"
#
# 동작:
#   1. PreToolUse hook으로 Bash 호출 직전 발동
#   2. 명령어 패턴 검사 (git commit / git push / az containerapp / az postgres / npm publish 등)
#   3. 위험 패턴이면 sensor-adversarial-pre-commit 통과 검증
#   4. FAIL이면 exit 2 (Claude Code reject) + 강제 메시지 (incident 박제 + 처음부터 + agent 위임)
#   5. PASS이면 exit 0 (통과)
#
# Exit:
#   0 — 통과 (위험 명령 아니거나 레드팀 통과)
#   2 — Reject (위험 명령 + 레드팀 미통과 또는 박제 안 됨)

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
INCIDENT_LOG="$ROOT/.claude/state/incident-log.jsonl"
VIOLATION_LOG="$ROOT/.claude/state/violation-log.jsonl"

# stdin으로 hook input 받음 (Claude Code Hook spec)
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('tool_input', {}).get('command', ''))" 2>/dev/null || echo "")

# 위험 패턴 검사
DANGEROUS=0
DANGEROUS_TYPE=""
case "$COMMAND" in
  *"git commit"*|*"git -C"*"commit"*)
    DANGEROUS=1; DANGEROUS_TYPE="git commit" ;;
  *"git push"*|*"git -C"*"push"*)
    DANGEROUS=1; DANGEROUS_TYPE="git push" ;;
  *"az containerapp update"*|*"az containerapp secret"*|*"az containerapp revision"*)
    DANGEROUS=1; DANGEROUS_TYPE="azure infra mutation" ;;
  *"az postgres"*"create"*|*"az postgres"*"delete"*)
    DANGEROUS=1; DANGEROUS_TYPE="azure postgres mutation" ;;
  # 2026-05-29 verifier 보강: 이 레포는 GCP 배포 — gcloud run deploy가 현 1차 배포 경로인데
  #   case에 없어 레드팀 0회 통과하던 결함. (Azure는 2026-05-27 GCP 마이그레이션으로 decommission 예정)
  *"gcloud run deploy"*|*"gcloud run services update"*|*"gcloud sql"*|*"gcloud secrets"*)
    DANGEROUS=1; DANGEROUS_TYPE="gcloud infra mutation" ;;
  *"npm publish"*|*"npx -p"*"publish"*)
    DANGEROUS=1; DANGEROUS_TYPE="npm publish" ;;
  *"polar product"*"create"*|*"polar webhook"*"update"*)
    DANGEROUS=1; DANGEROUS_TYPE="polar mutation" ;;
esac

# 안전한 명령은 즉시 통과
if [ "$DANGEROUS" -eq 0 ]; then
  exit 0
fi

# 위험 명령 → 레드팀 검증
echo "🛡 [pretooluse-redteam-gate] 위험 명령 검출: $DANGEROUS_TYPE" >&2
echo "   command: $(echo "$COMMAND" | head -c 100)" >&2

# sensor-adversarial-pre-commit 발동
ADV_OUT=$(bash "$ROOT/.claude/scripts/sensor-adversarial-pre-commit.sh" 2>&1)
ADV_RC=$?

if [ "$ADV_RC" -ge 2 ]; then
  # FAIL — reject
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # incident 박제
  bash "$ROOT/.claude/scripts/incident-log.sh" workflow critical sensor \
    "PreToolUse REJECT: $DANGEROUS_TYPE 시도 + sensor-adversarial FAIL (exit=$ADV_RC). 명령: $(echo "$COMMAND" | head -c 80)" \
    "처음부터 재진행 + agent 위임 강제" 2>/dev/null || true

  # violation-log 별도 시계열 박제 (장애 리포트)
  mkdir -p "$(dirname "$VIOLATION_LOG")"
  printf '{"ts":"%s","type":"redteam_reject","command_type":"%s","adversarial_exit":%s,"command_preview":%s}\n' \
    "$TS" "$DANGEROUS_TYPE" "$ADV_RC" \
    "$(echo "$COMMAND" | head -c 200 | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    >> "$VIOLATION_LOG"

  # Claude에게 강제 메시지 전달 (stderr — Claude가 다음 turn에서 봄)
  cat >&2 <<EOF

❌ REJECT — 레드팀 검증 미통과 ($DANGEROUS_TYPE)
   sensor-adversarial-pre-commit exit=$ADV_RC (FAIL principles 발견)

📋 강제 절차 (사용자 명시 2026-05-06 묶음 NN):
   1. 본 도구 호출 즉시 중단
   2. 하려던 절차 처음부터 재진행
   3. 적절한 agent 위임 (Task tool):
      - commit/push → grimoire-qa agent (검증 후 commit)
      - 인프라 변경 → grimoire-server agent + infra-mutation-guard skill
      - npm publish → grimoire-qa agent (배포 직전 회귀 검증)
   4. incident-log + violation-log 자동 박제 완료
   5. agent 결과 받은 후 다시 시도

📁 박제:
   - incident-log: $INCIDENT_LOG
   - violation-log: $VIOLATION_LOG
EOF

  exit 2
fi

# PASS 또는 WARN — 통과
echo "✅ [pretooluse-redteam-gate] 레드팀 통과 (exit=$ADV_RC) — $DANGEROUS_TYPE 진행 허용" >&2
exit 0
