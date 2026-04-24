#!/bin/bash
# PreCompact 훅 — ProjectGrimoire 컨텍스트 압축 직전

MEMORY_DIR="$HOME/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/memory"
PROJECT_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire"

TODAY=$(date "+%Y-%m-%d")
NOW_TIME=$(date "+%H:%M")

HAS_TODAY_COMMITS=false
for REPO in grimoire-server grimoire-web grimoire-ios; do
  REPO_PATH="$PROJECT_DIR/$REPO"
  if [ -d "$REPO_PATH/.git" ]; then
    COUNT=$(cd "$REPO_PATH" && git log --since="$TODAY 00:00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "$COUNT" -gt 0 ]; then
      HAS_TODAY_COMMITS=true
      break
    fi
  fi
done

if [ "$HAS_TODAY_COMMITS" = true ]; then
  echo ""
  echo "🚨 [Grimoire] 컨텍스트 압축 감지 ($NOW_TIME)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "장시간 세션으로 컨텍스트가 압축됩니다."
  echo ""
  echo "▶ 지금 즉시 project_session 메모리를 Write 도구로 갱신하세요."
  echo "  - 이번 세션에서 한 작업 요약"
  echo "  - 최신 커밋 해시"
  echo "  - 남은 작업 목록"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi
