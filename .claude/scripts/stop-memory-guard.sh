#!/bin/bash
# Stop 훅 — ProjectGrimoire 세션 종료 직전 메모리 갱신 여부 검증

MEMORY_DIR="$HOME/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/memory"
PROJECT_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire"
REPOS="grimoire-server grimoire-web grimoire-ios"

TODAY=$(date "+%Y-%m-%d")

# project_state 또는 project_session 파일 중 가장 최신 것
LATEST_MEMORY_FILE=$(ls -t "$MEMORY_DIR"/project_state_*.md "$MEMORY_DIR"/project_session_*.md "$MEMORY_DIR"/project_remaining_tasks.md 2>/dev/null | head -1)
if [ -z "$LATEST_MEMORY_FILE" ]; then
  echo "🚨 [ProjectGrimoire] STOP 차단: project_state/session 메모리 파일이 없습니다."
  exit 0
fi
MEMORY_TODAY=$(stat -f "%Sm" -t "%Y-%m-%d" "$LATEST_MEMORY_FILE" 2>/dev/null)

HAS_TODAY_COMMITS=false
for REPO in $REPOS; do
  REPO_PATH="$PROJECT_DIR/$REPO"
  if [ -d "$REPO_PATH/.git" ]; then
    COUNT=$(cd "$REPO_PATH" && git log --since="$TODAY 00:00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "$COUNT" -gt 0 ]; then
      HAS_TODAY_COMMITS=true
      break
    fi
  fi
done

if [ "$HAS_TODAY_COMMITS" = true ] && [ "$MEMORY_TODAY" != "$TODAY" ]; then
  echo ""
  echo "🚨🚨🚨 [ProjectGrimoire] STOP 경고: 오늘 커밋이 있는데 메모리 미갱신 🚨🚨🚨"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "오늘 날짜: $TODAY"
  echo "메모리 최종 갱신: $MEMORY_TODAY ($(basename $LATEST_MEMORY_FILE))"
  echo ""
  echo "❌ 지금 종료하면 이번 세션 작업이 다음 세션에서 유실됩니다."
  echo "❌ 반드시 project_state/session 메모리를 Write 도구로 갱신한 뒤 종료하세요."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
else
  echo "✅ [ProjectGrimoire] 메모리 갱신 상태 정상. 종료 가능."
fi
