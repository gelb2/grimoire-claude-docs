#!/bin/bash
# pretooluse-edit-write-guard.sh — 메인 Claude Edit/Write 차단 가드 (2026-05-29 재작성, 우회 키워드 제거)
#
# 사용자 명시 2026-05-29 (거짓 PASS 사태 후):
#   메인 = 오케스트레이션·메모리·읽기검증만. 코드/배포/qa/빌드 = 에이전트.
#   하네스(.claude) = 부트스트랩 플래그 ON이면 메인, OFF면 grimoire-harness 에이전트.
#   ※ 옛 버전의 "직전 user 메시지 키워드(진행해/위임) 우회"는 5/8~5/10 폐기 원인이라 완전 제거.
#
# 동작:
#   1. stdin JSON에서 tool_input.file_path + isSidechain 추출
#   2. isSidechain=true (에이전트 내부 호출)는 무조건 통과 — 에이전트는 작업 주체
#   3. pretooluse-main-whitelist.sh 로 file_path 분류
#   4. ALLOW면 통과(exit 0), BLOCK:<agent>면 차단(exit 2) + 위임 메시지 + violation 박제
#
# Exit: 0 통과 / 2 차단(Claude Code reject)

set -uo pipefail
ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
WHITELIST="$ROOT/.claude/scripts/pretooluse-main-whitelist.sh"
VIOLATION_LOG="$ROOT/.claude/state/edit-write-violation.jsonl"
mkdir -p "$(dirname "$VIOLATION_LOG")"

INPUT=$(cat 2>/dev/null)
[ -z "$INPUT" ] && exit 0

FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read()); print(d.get('tool_input',{}).get('file_path',''))
except: print('')" 2>/dev/null || echo "")
TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read()); print(d.get('tool_name',''))
except: print('')" 2>/dev/null || echo "")
# 2026-05-29 verifier 실측: hook stdin엔 isSidechain 키 없음(메인/에이전트 공통). sub-agent엔 agent_id 주입됨(메인 없음).
# → agent_id 존재 = sub-agent = 작업 주체 → 통과. (이전 isSidechain 판별은 항상 False라 에이전트 마비였음)
AGENT_ID=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read()); print(d.get('agent_id',''))
except: print('')" 2>/dev/null || echo "")

# sub-agent 내부 호출 = 작업 주체이므로 통과
[ -n "$AGENT_ID" ] && exit 0
[ -z "$FILE_PATH" ] && exit 0
[ ! -x "$WHITELIST" ] && exit 0   # 분류기 없으면 fail-open (가드 자체 결함이 작업 막지 않게)

VERDICT=$(bash "$WHITELIST" file "$FILE_PATH" 2>/dev/null || echo "ALLOW")

[ "$VERDICT" = "ALLOW" ] && exit 0

# BLOCK:<agent> — 차단
AGENT="${VERDICT#BLOCK:}"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"ts":"%s","type":"main_edit_blocked","tool":"%s","file":"%s","route":"%s"}\n' \
  "$TS" "$TOOL_NAME" "$FILE_PATH" "$AGENT" >> "$VIOLATION_LOG" 2>/dev/null || true

if [ "$AGENT" = "USER_APPROVAL" ]; then
  cat >&2 <<EOF
REJECT — PLANNING_GRIMOIRE.md는 사용자 승인 영역
  $TOOL_NAME 차단 (file: $FILE_PATH)
  → grimoire-planner 권고 박제 후 사용자 명시 필수
EOF
  exit 2
fi

cat >&2 <<EOF
REJECT — 메인 Claude 직접 $TOOL_NAME 차단 (코드/배포/qa/빌드/하네스 = 에이전트 영역)
  file: $FILE_PATH
  위임 대상: $AGENT 에이전트

강제 절차 (사용자 명시 2026-05-29 — 메인=오케스트레이션만):
  1. 본 도구 호출 중단
  2. Task tool 로 $AGENT 에이전트 위임
  3. 에이전트 작업 → grimoire-verifier 독립 검증 → 메인은 결과 취합만

(우회 키워드 없음 — 5/8~5/10 우회 구멍이 가드 폐기 원인이었음. 하네스 수정이 필요하면
 .claude/state/harness-bootstrap.flag 부트스트랩 모드 또는 grimoire-harness 위임)
박제: $VIOLATION_LOG
EOF
exit 2
