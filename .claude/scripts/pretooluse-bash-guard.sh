#!/bin/bash
# pretooluse-bash-guard.sh — 메인 Claude Bash 변경성 명령 차단 가드 (2026-05-29 재작성)
#
# 사용자 명시 2026-05-29: 메인 = 오케스트레이션·읽기검증만. 코드/배포/qa/빌드 = 에이전트.
#   Bash 중 변경성(commit/push/deploy/test/build/리다이렉트 파일쓰기) = 차단.
#   읽기전용(curl/git status/log/ls-remote/cat/grep 등) = 통과.
#   verifier 1차 검증 GAP D 반영 — Bash 리다이렉트로 코드영역 파일쓰기 우회 차단.
#
# 동작: stdin JSON에서 command 추출 → main-whitelist 분류 → BLOCK이면 exit 2.
#   isSidechain=true(에이전트 내부)는 무조건 통과.
# Exit: 0 통과 / 2 차단

set -uo pipefail
ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
WHITELIST="$ROOT/.claude/scripts/pretooluse-main-whitelist.sh"
VIOLATION_LOG="$ROOT/.claude/state/bash-guard-violation.jsonl"
mkdir -p "$(dirname "$VIOLATION_LOG")"

INPUT=$(cat 2>/dev/null)
[ -z "$INPUT" ] && exit 0

COMMAND=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read()); print(d.get('tool_input',{}).get('command',''))
except: print('')" 2>/dev/null || echo "")
# 2026-05-29 verifier 실측(hook stdin 덤프): Claude Code PreToolUse hook stdin엔 isSidechain 키가 없음
# (메인/에이전트 공통 부재). 대신 sub-agent 호출에만 agent_id/agent_type 필드가 주입됨(메인 호출엔 없음).
# → agent_id 존재 = sub-agent = 작업 주체 → 통과. (이전 isSidechain 판별은 항상 False라 에이전트 마비였음)
AGENT_ID=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read()); print(d.get('agent_id',''))
except: print('')" 2>/dev/null || echo "")

# sub-agent 내부 호출 = 작업 주체 → 통과
[ -n "$AGENT_ID" ] && exit 0
[ -z "$COMMAND" ] && exit 0
[ ! -x "$WHITELIST" ] && exit 0   # 분류기 없으면 fail-open (가드 결함이 작업 막지 않게)

VERDICT=$(bash "$WHITELIST" bash "$COMMAND" 2>/dev/null || echo "ALLOW")
[ "$VERDICT" = "ALLOW" ] && exit 0

REASON="${VERDICT#BLOCK:}"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# 명령 앞부분만 박제 (secret 노출 방지 — 60자)
CMD_HEAD=$(printf '%s' "$COMMAND" | head -c 60 | tr -d '"' | tr '\n' ' ')
printf '{"ts":"%s","type":"main_bash_blocked","reason":"%s","cmd_head":"%s"}\n' \
  "$TS" "$REASON" "$CMD_HEAD" >> "$VIOLATION_LOG" 2>/dev/null || true

# 변경성 분류별 위임 대상
case "$REASON" in
  mutating-git|deploy) AGENT="grimoire-infrastructure (또는 도메인 에이전트)" ;;
  test-build) AGENT="grimoire-qa / grimoire-server / grimoire-web" ;;
  bash-file-write-codearea) AGENT="grimoire-server / grimoire-web (해당 코드영역 도메인)" ;;
  grimoire-harness) AGENT="grimoire-harness (하네스 영역, 부트스트랩 OFF)" ;;
  *) AGENT="해당 도메인 에이전트" ;;
esac

cat >&2 <<EOF
REJECT — 메인 Claude 직접 Bash 변경성 명령 차단 ($REASON)
  cmd: ${CMD_HEAD}...
  위임 대상: $AGENT

강제 절차 (사용자 명시 2026-05-29 — 메인=오케스트레이션·읽기검증만):
  1. 본 명령 중단
  2. Task tool 로 위 에이전트 위임 (코드/배포/빌드/마이그레이션)
  3. 에이전트 작업 → grimoire-verifier 독립 검증 → 메인은 취합

읽기전용 검증(curl/git status/log/ls-remote/cat/grep)은 메인 직접 허용.
하네스 수정은 부트스트랩 플래그 또는 grimoire-harness 위임.
박제: $VIOLATION_LOG
EOF
exit 2
