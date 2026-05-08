#!/bin/bash
# pretooluse-main-whitelist.sh — 메인 LLM 도구 호출 화이트리스트 강제 (PP-13)
#
# 사용자 명시 (2026-05-08 본 세션 후속):
# > "메인은 그냥 시발 아무것도 못 하게 권한 박아버려"
# > "메인이 할 수 있는 일은 다 틀어 막으라고"
# > "직접 코드 수정, 스크립트 수정, 아무튼 씨발 뭐든 다 수정하는거 절대 금지"
# > "내 명령이 내려오면 에이전트로 내려갈 거 아니야 그러면 세션 터지는건 피할거니까"
#
# 본질:
# - 메인 = 지휘자 (사용자 명령 → agent 위임 → 결과 종합 → 보고)
# - agent = 실 작업 (각 도메인 책임)
# - 컨텍스트 격리 = 메인 컨텍스트 안정 + agent 컨텍스트 분리 = 세션 터짐 회피
#
# 동작:
# 1) stdin JSON에서 tool_name + tool_input 추출
# 2) isSidechain=True (agent 안 호출) → 통과
# 3) 화이트리스트 매칭:
#    - Read / Glob / Grep / SlashCommand / Task / Agent / TodoWrite / WebFetch / WebSearch / Skill → 통과
#    - Bash 검증 명령 (^git status/log/diff/show/fetch/branch/checkout/commit, ^ls, ^cat, ^head, ^tail, ^grep, ^awk, ^find, ^echo, ^pwd, ^which, ^ps, ^curl ...)
#    - Bash sensor 호출 (^bash .claude/scripts/sensor-, ^bash .claude/scripts/incident-log)
#    - Bash commit/push develop (git commit, git push origin develop)
#    - Edit/Write 메타 영역 (memory/, knowledge/, root .md, .claude/state/)
# 4) 화이트리스트 외 + 우회 키워드 X → exit 2 (차단)
# 5) main-blocked-log 자동 박제

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
VIOLATION_LOG="$ROOT/.claude/state/main-blocked-log.jsonl"
mkdir -p "$(dirname "$VIOLATION_LOG")"

INPUT=$(cat 2>/dev/null)
[ -z "$INPUT" ] && exit 0

# isSidechain 검사 — agent 안 호출은 통과
SIDECHAIN=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(d.get('isSidechain', False))
except: print('False')" 2>/dev/null || echo "False")

if [ "$SIDECHAIN" = "True" ]; then
  exit 0
fi

TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(d.get('tool_name',''))
except: print('')" 2>/dev/null || echo "")

# 화이트리스트 도구 (검증/조사/위임 영역) — 통과
case "$TOOL_NAME" in
  Read|Glob|Grep|SlashCommand|Task|Agent|TodoWrite|WebFetch|WebSearch|Skill)
    exit 0
  ;;
esac

# 우회 키워드 검사 함수 — 사용자 명시 (2026-05-08) "허용패턴만 통과로 남겨놔"로 제거됨.
# 화이트리스트 외 = 무조건 차단 (백도어 X). 다음 옵션:
#   1. 사용자 직접 박제
#   2. agent 위임 (Task tool로 적합 agent 호출, isSidechain=True로 통과)

# Bash 검증 명령 화이트리스트
if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(d.get('tool_input',{}).get('command',''))
except: print('')" 2>/dev/null || echo "")

  WHITELIST_PATTERNS=(
    '^git\s+(status|log|diff|show|fetch|branch|checkout|stash|reflog|blame|ls-files|rev-parse|describe|tag|remote|config\s+(--get|--list))\b'
    '^git\s+commit\b'
    '^git\s+push\s+origin\s+develop\b'
    '^git\s+add\b'
    '^git\s+restore\s+--staged\b'
    '^ls\b'
    '^cat\b'
    '^head\b'
    '^tail\b'
    '^grep\b'
    '^awk\b'
    '^sed\s+-n\b'
    '^find\b'
    '^echo\b'
    '^pwd\b'
    '^which\b'
    '^ps\b'
    '^wc\b'
    '^sort\b'
    '^uniq\b'
    '^cut\b'
    '^tr\b'
    '^xargs\b'
    '^jq\b'
    '^python3\s+-c'
    '^bash\s+\S*sensor-'
    '^bash\s+\S*incident-log'
    '^bash\s+\S*update-harness-inventory'
    '^bash\s+\S*deploy-precheck'
    '^bash\s+eval/scripts/'
    '^curl\s+(-s|-o|-w|-X\s+(GET|HEAD)|--max-time)'
    '^az\s+\S+\s+(show|list)\b'
    '^az\s+containerapp\s+(show|list|logs\s+show|env\s+show)\b'
    '^az\s+containerapp\s+revision\s+(show|list)\b'
    '^az\s+postgres\s+\S+\s+(show|list)\b'
    '^gh\s+(run\s+(list|view|watch)|pr\s+(list|view|status)|api\s+repos)\b'
    '^docker\s+(ps|images|inspect|logs|version|info)\b'
    '^npm\s+(list|run\s+lint|run\s+test:?\S*|test|--version)\b'
    '^npx\s+(prisma|tsc)\s+(status|--version|--noEmit)\b'
    '^make\s+(help|status|list)\b'
    '^until\b'
    '^sleep\b'
    '^date\b'
    '^test\b'
    '^\['
    '^\(\('
  )

  for pattern in "${WHITELIST_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qE "$pattern"; then
      exit 0
    fi
  done

  # 우회 키워드 제거 (2026-05-08 사용자 명시 "허용패턴만")

  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  ESCAPED_CMD=$(echo "$COMMAND" | head -c 200 | sed 's/"/\\"/g; s/\\/\\\\/g')
  printf '{"ts":"%s","tool":"Bash","type":"main_whitelist_violation","command":"%s"}\n' \
    "$TS" "$ESCAPED_CMD" >> "$VIOLATION_LOG"

  cat >&2 <<EOF
[메인 화이트리스트 차단 PP-13] Bash 명령이 메인 화이트리스트 외 영역.

차단 명령: $(echo "$COMMAND" | head -c 200)

화이트리스트 영역 (검증/조회/sensor/commit/push develop):
- 검증: git status/log/diff/show, ls, cat, head, tail, grep, awk, find, echo, ps, wc 등
- 조회: curl --max-time, az * show/list, gh run list, docker ps/images, jq
- sensor: bash .claude/scripts/sensor-*, incident-log
- commit/push develop: git commit, git push origin develop, git add
- 메타: npm list, npm run lint, npm test, npx prisma status, npx tsc --noEmit, make help/status

mutation 명령 (deploy/az containerapp update/git push main/migrate 등) = grimoire-infrastructure 또는 grimoire-server agent 위임 강제.

우회 (긴급 시): 사용자 직전 메시지에 "agent로|위임|처리해|진행해|메인 직접|직접 Edit|직접 작업|박아|박아버려|박제해|틀어 막|화이트리스트" 포함.

박제: $VIOLATION_LOG
EOF
  exit 2
fi

# Edit/Write — 메타 영역 화이트리스트
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "NotebookEdit" ]; then
  FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(d.get('tool_input',{}).get('file_path',''))
except: print('')" 2>/dev/null || echo "")

  case "$FILE_PATH" in
    */.claude/projects/*/memory/*) exit 0 ;;
    */ProjectGrimoire/.claude/state/*) exit 0 ;;
    */ProjectGrimoire/.claude/knowledge/*) exit 0 ;;
    */ProjectGrimoire/HANDOVER_NEXT_SESSION.md) exit 0 ;;
    */ProjectGrimoire/CHANGELOG.md) exit 0 ;;
    */ProjectGrimoire/SYNC_STATUS.md) exit 0 ;;
    */ProjectGrimoire/MEMORY.md) exit 0 ;;
    */ProjectGrimoire/README.md) exit 0 ;;
    */ProjectGrimoire/.gitignore) exit 0 ;;
    */ProjectGrimoire/PLANNING_GRIMOIRE.md)
      cat >&2 <<EOF
[메인 화이트리스트 차단 PP-13] PLANNING_GRIMOIRE.md는 사용자 승인 영역 (PP-7 정합).
EOF
      exit 2
    ;;
  esac

  # 우회 키워드 제거

  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '{"ts":"%s","tool":"%s","type":"main_whitelist_violation","file":"%s"}\n' \
    "$TS" "$TOOL_NAME" "$FILE_PATH" >> "$VIOLATION_LOG"

  cat >&2 <<EOF
[메인 화이트리스트 차단 PP-13] $TOOL_NAME 호출이 메인 화이트리스트 외 영역.

차단 file: $FILE_PATH

화이트리스트 영역 (메타):
- 메모리 (~/.claude/projects/.../memory/)
- .claude/state/, .claude/knowledge/
- root: HANDOVER, CHANGELOG, SYNC_STATUS, MEMORY, README, .gitignore

코드 영역 (server/web/eval/.claude/scripts/.claude/skills/.claude/agents/.claude/settings.json) = agent 위임 강제. PP-7 라우팅 매트릭스 정합.

우회 (긴급 시): 사용자 직전 메시지에 "agent로|위임|처리해|진행해|메인 직접|직접 Edit|직접 작업|박아|박아버려|박제해|틀어 막|화이트리스트" 포함.

박제: $VIOLATION_LOG
EOF
  exit 2
fi

# 기타 도구 (MultiEdit 등) — 화이트리스트 외, 차단
# 우회 키워드 제거

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"ts":"%s","tool":"%s","type":"main_whitelist_violation_unknown_tool"}\n' \
  "$TS" "$TOOL_NAME" >> "$VIOLATION_LOG"

cat >&2 <<EOF
[메인 화이트리스트 차단 PP-13] $TOOL_NAME = 화이트리스트 외 도구.

화이트리스트 도구: Read / Glob / Grep / SlashCommand / Task / Agent / TodoWrite / WebFetch / WebSearch / Skill / Bash (검증) / Edit/Write (메타)

박제: $VIOLATION_LOG
EOF
exit 2
