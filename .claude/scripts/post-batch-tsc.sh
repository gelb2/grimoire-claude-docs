#!/usr/bin/env bash
# post-batch-tsc.sh — PostToolBatch hook
#
# 동작:
# 1) parallel tool batch 완료 후 발동
# 2) debounce: 60초 내 중복 실행 skip (lock 파일 기반)
# 3) server + web 양쪽 tsc 한 번씩 실행
# 4) Claude 흐름 차단 안 함 (exit 0 유지, 실패 시 stderr 경고만)
#
# 의도: 기존 post-edit-tsc.sh가 매 Edit/Write마다 호출되는 비효율 보완.
# parallel batch (예: 5개 Edit 동시) 시 PostToolUse는 5번 실행되지만,
# PostToolBatch는 1번만 발동 → debounce로 PostToolUse 5번 중복도 스킵 가능.
#
# Anthropic 명세: PostToolBatch는 batch 완료 후, 다음 모델 호출 전 발동.
# matcher 미지원 (모든 batch에 발동). 본 스크립트가 자체 debounce로 효율 확보.

set +e

LOCK_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/state"
LOCK_FILE="$LOCK_DIR/post-batch-tsc.lock"
DEBOUNCE_SEC=60

mkdir -p "$LOCK_DIR"

# debounce: 60초 내 중복 실행 skip
if [ -f "$LOCK_FILE" ]; then
  LAST=$(cat "$LOCK_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  DIFF=$((NOW - LAST))
  if [ "$DIFF" -lt "$DEBOUNCE_SEC" ]; then
    # 조용히 skip (debounce)
    exit 0
  fi
fi

date +%s > "$LOCK_FILE"

# stdin JSON 일단 read (사용은 안 하지만 hook 인터페이스 정합)
[ ! -t 0 ] && cat > /dev/null 2>/dev/null || true

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# server + web 양쪽 tsc (병렬 실행)
SERVER_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server"
WEB_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web"

run_tsc() {
  local repo="$1"
  local name
  name=$(basename "$repo")
  if [ ! -d "$repo" ]; then
    return 0
  fi
  local out
  out=$(cd "$repo" && npx tsc --noEmit 2>&1)
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    {
      echo "[post-batch-tsc] $name: tsc 실패 (exit $rc). 최근 20줄:"
      echo "$out" | tail -n 20
    } >&2
  fi
}

# 병렬 실행 (background + wait)
run_tsc "$SERVER_DIR" &
PID1=$!
run_tsc "$WEB_DIR" &
PID2=$!
wait "$PID1" "$PID2"

exit 0
