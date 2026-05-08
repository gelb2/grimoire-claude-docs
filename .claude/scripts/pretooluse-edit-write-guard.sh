#!/bin/bash
# pretooluse-edit-write-guard.sh — 메인 Claude Edit/Write 자동 차단 + agent 위임 강제 (PP-7)
#
# 사용자 명시 (2026-05-06): "내가 스킬이랑 에이전트 일일이 쓰라고 매일 쓰면 그게 베이비시팅이지 하네스야?"
# = 사용자 매번 강제 = 베이비시팅. 진짜 하네스 = 자동 강제 hook이 사용자 명시 없이 작동.
#
# 동작:
# 1) stdin JSON에서 tool_input.file_path 추출
# 2) isSidechain=true (agent 안)는 통과
# 3) file_path 기반 작업 의도 자동 분류:
#    - grimoire-server/src/**, .claude/skills/*, .claude/scripts/* → grimoire-server agent 위임
#    - grimoire-web/src/** → grimoire-web agent 위임
#    - eval/tasks*, eval/scripts/* → grimoire-qa agent 위임
#    - reports/QA_REPORT* → grimoire-qa
#    - reports/PLANNER_REPORT* → grimoire-planner
#    - reports/COST_AUDIT* → grimoire-cost-accountant
#    - reports/VISUAL_CANON* → grimoire-visual-canon-keeper
#    - reports/DEV_REPORT* → grimoire-server
#    - PLANNING_GRIMOIRE.md → 사용자 승인 영역 (메인 직접 X)
#    - 기타 (memory/, knowledge/, root .md, .claude/agents/) → 메타 영역, 통과
# 4) 사용자 직전 메시지에 "agent로|위임|처리해|진행해|메인 직접|직접 Edit" 키워드 X
#    + 분류 결과가 agent 위임 영역이면 → exit 2 (차단) + 강제 메시지
# 5) violation incident-log.sh 박제

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
INCIDENT="$ROOT/.claude/scripts/incident-log.sh"
VIOLATION_LOG="$ROOT/.claude/state/edit-write-violation.jsonl"
mkdir -p "$(dirname "$VIOLATION_LOG")"

INPUT=$(cat 2>/dev/null)
[ -z "$INPUT" ] && exit 0

FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(d.get('tool_input',{}).get('file_path',''))
except: print('')" 2>/dev/null || echo "")

TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(d.get('tool_name',''))
except: print('')" 2>/dev/null || echo "")

# isSidechain 검사 — agent 안 호출은 통과
SIDECHAIN=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(d.get('isSidechain', False))
except: print('False')" 2>/dev/null || echo "False")

if [ "$SIDECHAIN" = "True" ]; then
  exit 0  # agent 안에서는 통과
fi

[ -z "$FILE_PATH" ] && exit 0

# 작업 의도 분류 (file_path 기반)
EXPECTED_AGENT=""
case "$FILE_PATH" in
  *PLANNING_GRIMOIRE.md*) EXPECTED_AGENT="USER_APPROVAL" ;;
  *grimoire-server/src/*) EXPECTED_AGENT="grimoire-server" ;;
  *grimoire-server/docs/*) EXPECTED_AGENT="grimoire-server" ;;
  *grimoire-server/test/*) EXPECTED_AGENT="grimoire-server" ;;
  *grimoire-web/src/*) EXPECTED_AGENT="grimoire-web" ;;
  *grimoire-web/docs/*) EXPECTED_AGENT="grimoire-web" ;;
  *grimoire-web/app/*) EXPECTED_AGENT="grimoire-web" ;;
  # .claude/ 하네스 영역 — grimoire-infrastructure (사용자 명시 2026-05-08)
  *.claude/skills/*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/sensor-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/pretooluse-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/incident-log*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/stop-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/check-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/skill-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/post-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/user-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/pre-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/loop-detection-tracker*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/posttooluse-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/subagent-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/instructions-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/generate-*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/scripts/statusline*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *.claude/settings.json*) EXPECTED_AGENT="grimoire-infrastructure" ;;
  *eval/tasks*) EXPECTED_AGENT="grimoire-qa" ;;
  *eval/scripts/*) EXPECTED_AGENT="grimoire-qa" ;;
  *reports/QA_REPORT*) EXPECTED_AGENT="grimoire-qa" ;;
  *reports/PLANNER_REPORT*) EXPECTED_AGENT="grimoire-planner" ;;
  *reports/COST_AUDIT*) EXPECTED_AGENT="grimoire-cost-accountant" ;;
  *reports/VISUAL_CANON*) EXPECTED_AGENT="grimoire-visual-canon-keeper" ;;
  *reports/DEV_REPORT*) EXPECTED_AGENT="grimoire-server" ;;
  *)
    # 메타 영역 (memory/, knowledge/, root .md, .claude/agents/, .claude/AGENTS.md 등)
    # 메인 직접 작업 가능
    exit 0
  ;;
esac

# PLANNING_GRIMOIRE는 사용자 승인 영역 — 차단
if [ "$EXPECTED_AGENT" = "USER_APPROVAL" ]; then
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '{"ts":"%s","type":"planning_direct_edit","tool":"%s","file":"%s"}\n' \
    "$TS" "$TOOL_NAME" "$FILE_PATH" >> "$VIOLATION_LOG"

  if [ -x "$INCIDENT" ]; then
    bash "$INCIDENT" workflow critical sensor \
      "PreToolUse REJECT: PLANNING_GRIMOIRE.md 직접 Edit 시도 ($TOOL_NAME)" \
      "사용자 승인 후만 가능" >/dev/null 2>&1 || true
  fi

  cat >&2 <<EOF
REJECT — PLANNING_GRIMOIRE.md는 사용자 승인 영역
  $TOOL_NAME 호출 차단 (file: $FILE_PATH)
  → grimoire-planner agent로 권고 박제 후 사용자 명시 필수

  우회 (긴급 시): 사용자 직전 메시지에 "직접 Edit" 키워드 명시
EOF
  exit 2
fi

# 사용자 직전 메시지에 위임 명시 키워드 검색 (jsonl 직전 user message)
JSONL_DIR="$HOME/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire"
LATEST_JSONL=$(ls -t "$JSONL_DIR"/*.jsonl 2>/dev/null | head -1)
USER_DELEGATION_OK=0

if [ -n "$LATEST_JSONL" ] && [ -f "$LATEST_JSONL" ]; then
  # 직전 user message에 위임 키워드 있는지
  LAST_USER_MSG=$(LATEST_JSONL_PATH="$LATEST_JSONL" python3 <<'PYEOF'
import json
import os

jsonl = os.environ.get('LATEST_JSONL_PATH', '')
last_user = ""
try:
    with open(jsonl) as f:
        for line in f:
            try:
                o = json.loads(line)
            except Exception:
                continue
            m = o.get('message', {})
            if isinstance(m, dict) and m.get('role') == 'user':
                content = m.get('content', '')
                if isinstance(content, list):
                    for c in content:
                        if isinstance(c, dict) and c.get('type') == 'text':
                            last_user = c.get('text', '')
                else:
                    last_user = str(content)
except Exception:
    pass
print(last_user[:1000])
PYEOF
)
  if echo "$LAST_USER_MSG" | grep -qE "agent로|위임|처리해|진행해|메인 직접|직접 Edit|직접 작업|박아|박아버려|박제해"; then
    USER_DELEGATION_OK=1
  fi
fi

# 사용자 위임 명시 있으면 통과 (메인 직접 진행 사용자 승인)
if [ "$USER_DELEGATION_OK" = "1" ]; then
  exit 0
fi

# 명시 없이 agent 위임 영역 직접 호출 → 차단
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"ts":"%s","type":"main_direct_in_agent_domain","tool":"%s","file":"%s","expected_agent":"%s"}\n' \
  "$TS" "$TOOL_NAME" "$FILE_PATH" "$EXPECTED_AGENT" >> "$VIOLATION_LOG"

if [ -x "$INCIDENT" ]; then
  bash "$INCIDENT" workflow critical sensor \
    "PreToolUse REJECT: 메인이 $EXPECTED_AGENT 책임 영역 직접 $TOOL_NAME 시도 (file: $FILE_PATH)" \
    "Task tool로 $EXPECTED_AGENT agent 위임 강제" >/dev/null 2>&1 || true
fi

cat >&2 <<EOF
REJECT — 메인 Claude 직접 작업 차단 ($EXPECTED_AGENT 책임 영역)
  tool: $TOOL_NAME
  file: $FILE_PATH

강제 절차 (사용자 명시 2026-05-06 PP-7):
  1. 본 도구 호출 즉시 중단
  2. Task tool로 $EXPECTED_AGENT agent 위임
  3. agent 결과 받은 후 메인은 commit/push만 수행

박제: $VIOLATION_LOG

우회 (긴급 시): 사용자 직전 메시지에 "agent로" / "위임" / "처리해" / "직접 Edit" 키워드 포함 시 통과
EOF

exit 2
