#!/bin/bash
# UserPromptSubmit 훅 — ProjectGrimoire
# 사용자 메시지마다 경량 체크. 30분 간격, 커밋 5개 이상 + 메모리 2시간 이상 미갱신 시 리마인더.

MEMORY_DIR="$HOME/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/memory"
PROJECT_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire"
REPOS="grimoire-server grimoire-web grimoire-ios"
MARKER_FILE="/tmp/grimoire_memory_last_remind"

NOW=$(date +%s)
if [ -f "$MARKER_FILE" ]; then
  LAST_REMIND=$(cat "$MARKER_FILE" 2>/dev/null)
  ELAPSED=$((NOW - LAST_REMIND))
  if [ "$ELAPSED" -lt 1800 ]; then
    exit 0
  fi
fi

LATEST_MEMORY_FILE=$(ls -t "$MEMORY_DIR"/project_session_*.md "$MEMORY_DIR"/project_remaining_tasks.md 2>/dev/null | head -1)
if [ -z "$LATEST_MEMORY_FILE" ]; then
  exit 0
fi
MEMORY_EPOCH=$(stat -f "%m" "$LATEST_MEMORY_FILE" 2>/dev/null)

TWO_HOURS_AGO=$(date -v-2H "+%Y-%m-%d %H:%M:%S")
RECENT_COMMITS=0
for REPO in $REPOS; do
  REPO_PATH="$PROJECT_DIR/$REPO"
  if [ -d "$REPO_PATH/.git" ]; then
    COUNT=$(cd "$REPO_PATH" && git log --since="$TWO_HOURS_AGO" --oneline 2>/dev/null | wc -l | tr -d ' ')
    RECENT_COMMITS=$((RECENT_COMMITS + COUNT))
  fi
done

GAP=$((NOW - MEMORY_EPOCH))
if [ "$RECENT_COMMITS" -ge 5 ] && [ "$GAP" -gt 7200 ]; then
  echo ""
  echo "⏰ [Grimoire] 중간 세이브 리마인더: 최근 2시간 커밋 ${RECENT_COMMITS}개, 메모리 갱신 $((GAP/3600))시간 전"
  echo "   장시간 세션입니다. 중간에 메모리를 갱신해두면 갑작스런 종료에도 안전합니다."
  echo ""
  echo "$NOW" > "$MARKER_FILE"
fi
