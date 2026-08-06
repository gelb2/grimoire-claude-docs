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
#   줄 1 (운영):
#     1. 메인 레포 브랜치 (claude-docs)
#     2. server / web develop ahead origin/main (배포 대기)
#     3. sensor-cost-margin 최근 상태
#     4. sensor-deploy-drift 최근 상태
#   줄 2 (KPI, 2026-05-01 #10_2 H3 강화):
#     5. Regression eval pass rate (baseline.csv tail)
#     6. EDD eval pass rate (edd-baseline.csv tail)
#     7. WARN 합계 (sensor-hits.jsonl sensor별 마지막 결과)

set +u

ROOT="/Users/sokol/Git/ProjectGrimoire"
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

# 5. Regression eval (baseline.csv 마지막 줄: ts,total,pass,fail,pass_rate)
REG_DATA="?"
REG_COL="$GRAY"
REG_FILE="$ROOT/eval/results/baseline.csv"
if [ -f "$REG_FILE" ]; then
  REG_LAST=$(tail -1 "$REG_FILE" 2>/dev/null)
  REG_TOTAL=$(echo "$REG_LAST" | awk -F',' '{print $2}')
  REG_PASS=$(echo "$REG_LAST" | awk -F',' '{print $3}')
  REG_RATE=$(echo "$REG_LAST" | awk -F',' '{print $5}')
  if [ -n "$REG_TOTAL" ] && [ -n "$REG_PASS" ]; then
    REG_DATA="${REG_PASS}/${REG_TOTAL}"
    case "$REG_RATE" in
      1.0|1.00*) REG_COL="$GREEN" ;;
      0.9*) REG_COL="$YELLOW" ;;
      *) REG_COL="$RED" ;;
    esac
  fi
fi

# 6. EDD eval (edd-baseline.csv 마지막 줄: ts,mode,runs,llm_judge,total,pass,fail,pass_rate)
EDD_DATA="?"
EDD_COL="$GRAY"
EDD_FILE="$ROOT/eval/results/edd-baseline.csv"
if [ -f "$EDD_FILE" ]; then
  EDD_LAST=$(tail -1 "$EDD_FILE" 2>/dev/null)
  EDD_TOTAL=$(echo "$EDD_LAST" | awk -F',' '{print $5}')
  EDD_PASS=$(echo "$EDD_LAST" | awk -F',' '{print $6}')
  EDD_RATE=$(echo "$EDD_LAST" | awk -F',' '{print $8}')
  if [ -n "$EDD_TOTAL" ] && [ -n "$EDD_PASS" ]; then
    EDD_DATA="${EDD_PASS}/${EDD_TOTAL}"
    case "$EDD_RATE" in
      1.0|1.00*) EDD_COL="$GREEN" ;;
      0.9*) EDD_COL="$YELLOW" ;;
      *) EDD_COL="$RED" ;;
    esac
  fi
fi

# 7. WARN 합계 (sensor-hits.jsonl 의 sensor별 마지막 결과 — Python 1회)
WARN_DATA="?"
WARN_COL="$GRAY"
HITS_FILE="$ROOT/.claude/state/sensor-hits.jsonl"
if [ -f "$HITS_FILE" ]; then
  WARN_OUT=$(python3 -c "
import json, sys
seen = {}
try:
    with open('$HITS_FILE') as f:
        for line in f:
            try:
                o = json.loads(line)
                s = o.get('sensor', '')
                r = o.get('result', '')
                if s and s not in ('unknown', '--quiet') and r in ('PASS','WARN','FAIL'):
                    seen[s] = r
            except Exception: pass
    w = sum(1 for r in seen.values() if r == 'WARN')
    f_ = sum(1 for r in seen.values() if r == 'FAIL')
    print(f'{w}W/{f_}F')
except Exception:
    print('?')
" 2>/dev/null)
  if [ -n "$WARN_OUT" ] && [ "$WARN_OUT" != "?" ]; then
    WARN_DATA="$WARN_OUT"
    # F가 1 이상이면 RED, W만 있으면 YELLOW, 없으면 GREEN
    if echo "$WARN_OUT" | grep -q "^[0-9]*W/0F$"; then
      if echo "$WARN_OUT" | grep -q "^0W/0F$"; then
        WARN_COL="$GREEN"
      else
        WARN_COL="$YELLOW"
      fi
    else
      WARN_COL="$RED"
    fi
  fi
fi

# 출력 (2줄)
printf "${BOLD}📚${RESET} [docs:${DOCS_BRANCH}] svr:${SVR_COL}${SVR_AHEAD}↑${RESET}/web:${WEB_COL}${WEB_AHEAD}↑${RESET} | 💰 ${COST_COL}${COST_DATA}${RESET} | 🚢 ${DRIFT_COL}${DRIFT_DATA}${RESET}\n"
printf "  🧪 reg:${REG_COL}${REG_DATA}${RESET} | 🤖 EDD:${EDD_COL}${EDD_DATA}${RESET} | ⚠️  ${WARN_COL}${WARN_DATA}${RESET}\n"

exit 0
