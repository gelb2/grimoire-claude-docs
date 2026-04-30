#!/usr/bin/env bash
# statusline.sh — Claude Code 상태바 (HARNESS §8.5)
#
# 동작 (공식 명세):
#   - settings.json statusLine 등록 (type=command, command=경로) → 자동 호출
#   - stdin: JSON (모델/컨텍스트/git/cost 등 25+ 필드)
#   - stdout: 1~2줄 (한 줄 권장, ANSI 색상 가능)
#   - 호출 빈도: assistant 메시지 후 + 권한 모드 변경 + Vim 토글, 300ms debounce
#   - 빠른 명령만 사용 (1초 미만, 외부 네트워크 호출 금지)
#
# 표시 항목 (Ambient Affordance, HARNESS §3):
#   1. 메인 레포 브랜치 (claude-docs)
#   2. server / web develop ahead origin/main (배포 대기)
#   3. sensor-cost-margin 최근 상태
#   4. sensor-deploy-drift 최근 상태

set +u

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
STATE="$ROOT/.claude/state"

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
GRAY="\033[90m"
BOLD="\033[1m"
RESET="\033[0m"

# stdin JSON 무시 (본 sh는 git/jsonl만 사용)
cat /dev/stdin > /dev/null 2>&1

# 1. claude-docs 브랜치
DOCS_BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo "?")

# 2. ahead 카운트 함수
get_ahead() {
  local repo="$1"
  if [ -d "$repo/.git" ]; then
    git -C "$repo" rev-list --count origin/main..origin/develop 2>/dev/null || echo "?"
  else
    echo "?"
  fi
}
SVR_AHEAD=$(get_ahead "$ROOT/grimoire-server")
WEB_AHEAD=$(get_ahead "$ROOT/grimoire-web")

ahead_color() {
  local n="$1"
  case "$n" in
    0) printf "$GREEN" ;;
    [1-5]) printf "$YELLOW" ;;
    "?") printf "$GRAY" ;;
    *) printf "$RED" ;;
  esac
}
SVR_COL=$(ahead_color "$SVR_AHEAD")
WEB_COL=$(ahead_color "$WEB_AHEAD")

# 3. sensor-cost-margin 최근 상태
COST_DATA="?"
COST_COL="$GRAY"
if [ -f "$STATE/cost-margin.jsonl" ]; then
  COST_LINE=$(tail -1 "$STATE/cost-margin.jsonl" 2>/dev/null)
  if [ -n "$COST_LINE" ]; then
    COST_STATUS=$(echo "$COST_LINE" | python3 -c "import json,sys
try: print(json.loads(sys.stdin.read()).get('status','?'))
except: print('?')" 2>/dev/null)
    COST_AVG=$(echo "$COST_LINE" | python3 -c "import json,sys
try: print(json.loads(sys.stdin.read()).get('avg','?'))
except: print('?')" 2>/dev/null)
    COST_DATA="$COST_STATUS $COST_AVG×"
    case "$COST_STATUS" in
      PASS) COST_COL="$GREEN" ;;
      WARN) COST_COL="$YELLOW" ;;
      FAIL) COST_COL="$RED" ;;
    esac
  fi
fi

# 4. sensor-deploy-drift 최근 상태
DRIFT_DATA="?"
DRIFT_COL="$GRAY"
if [ -f "$STATE/deploy-drift.jsonl" ]; then
  DRIFT_LINE=$(tail -1 "$STATE/deploy-drift.jsonl" 2>/dev/null)
  if [ -n "$DRIFT_LINE" ]; then
    DRIFT_STATUS=$(echo "$DRIFT_LINE" | python3 -c "import json,sys
try: print(json.loads(sys.stdin.read()).get('status','?'))
except: print('?')" 2>/dev/null)
    DRIFT_PASS=$(echo "$DRIFT_LINE" | python3 -c "import json,sys
try: print(json.loads(sys.stdin.read()).get('pass','?'))
except: print('?')" 2>/dev/null)
    DRIFT_WARN=$(echo "$DRIFT_LINE" | python3 -c "import json,sys
try: print(json.loads(sys.stdin.read()).get('warn','?'))
except: print('?')" 2>/dev/null)
    DRIFT_DATA="$DRIFT_STATUS ${DRIFT_PASS}P/${DRIFT_WARN}W"
    case "$DRIFT_STATUS" in
      PASS) DRIFT_COL="$GREEN" ;;
      WARN) DRIFT_COL="$YELLOW" ;;
      FAIL) DRIFT_COL="$RED" ;;
    esac
  fi
fi

# 출력 (한 줄)
printf "${BOLD}📚${RESET} [docs:${DOCS_BRANCH}] svr:${SVR_COL}${SVR_AHEAD}↑${RESET}/web:${WEB_COL}${WEB_AHEAD}↑${RESET} | 💰 ${COST_COL}${COST_DATA}${RESET} | 🚢 ${DRIFT_COL}${DRIFT_DATA}${RESET}\n"

exit 0
