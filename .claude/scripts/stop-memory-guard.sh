#!/bin/bash
# Stop 훅 — ProjectGrimoire 세션 종료 직전 메모리 갱신 여부 검증 (2026-04-30 #10 H10 강화)
#
# 절대 규칙 (.claude/AGENTS.md §1):
#   1. 코드 변경 → project_session_YYYYMMDD[_N].md 작성
#   2. MEMORY.md 인덱스에 해당 파일 추가
#   3. project_remaining_tasks.md 현행화 (7일 이상 stale 시 WARN)
#   4. 관련 상태 메모리 갱신
#
# H10 강화 사항:
#   - claude-docs 자체 commit 포함 (워크스페이스 루트 .git 검증)
#   - MEMORY.md 인덱스 오늘 세션 기록 박제 검증
#   - project_remaining_tasks.md 7일 이상 stale WARN
#   - grimoire-ios 제거 (ProjectGrimoire에 없음 — drift 해소)

MEMORY_DIR="$HOME/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/memory"
PROJECT_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire"
REPOS="grimoire-server grimoire-web"

TODAY=$(date "+%Y-%m-%d")

# 가장 최신 메모리 파일 (project_state / project_session / project_remaining_tasks)
LATEST_MEMORY_FILE=$(ls -t "$MEMORY_DIR"/project_state_*.md "$MEMORY_DIR"/project_session_*.md "$MEMORY_DIR"/project_remaining_tasks.md 2>/dev/null | head -1)
if [ -z "$LATEST_MEMORY_FILE" ]; then
  echo "🚨 [ProjectGrimoire] STOP 차단: project_state/session 메모리 파일이 없습니다."
  exit 0
fi
MEMORY_TODAY=$(stat -f "%Sm" -t "%Y-%m-%d" "$LATEST_MEMORY_FILE" 2>/dev/null)

# [1] 오늘 commit 검증 (server/web + claude-docs 워크스페이스 루트 포함)
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

# claude-docs 워크스페이스 루트 .git 별도 검증
if [ -d "$PROJECT_DIR/.git" ]; then
  COUNT=$(cd "$PROJECT_DIR" && git log --since="$TODAY 00:00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 0 ]; then
    HAS_TODAY_COMMITS=true
  fi
fi

# [2] 오늘 commit 있는데 메모리 미갱신 → 차단
if [ "$HAS_TODAY_COMMITS" = true ] && [ "$MEMORY_TODAY" != "$TODAY" ]; then
  echo ""
  echo "🚨🚨🚨 [ProjectGrimoire] STOP 경고: 오늘 커밋이 있는데 메모리 미갱신 🚨🚨🚨"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "오늘 날짜: $TODAY"
  echo "메모리 최종 갱신: $MEMORY_TODAY ($(basename $LATEST_MEMORY_FILE))"
  echo ""
  echo "❌ 지금 종료하면 이번 세션 작업이 다음 세션에서 유실됩니다."
  echo "❌ 반드시 project_session_${TODAY//-/}[_N].md 작성 + MEMORY.md 인덱스 추가 + project_remaining_tasks.md 현행화 후 종료하세요."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 0
fi

# [3] MEMORY.md 인덱스에 오늘 세션 박제 검증 (H10 강화)
MEMORY_INDEX="$MEMORY_DIR/MEMORY.md"
if [ "$HAS_TODAY_COMMITS" = true ] && [ -f "$MEMORY_INDEX" ]; then
  TODAY_COMPACT="${TODAY//-/}"  # 2026-04-30 → 20260430
  if ! grep -q "$TODAY_COMPACT" "$MEMORY_INDEX"; then
    echo ""
    echo "⚠️ [ProjectGrimoire] WARN: MEMORY.md에 오늘($TODAY) 세션 기록이 인덱스되지 않았습니다."
    echo "   .claude/AGENTS.md §1 절대 규칙: 'MEMORY.md 인덱스에 해당 파일 추가'"
    echo "   project_session_${TODAY_COMPACT}*.md 작성 후 MEMORY.md에 1줄 박제 필요."
    echo ""
  fi
fi

# [4] project_remaining_tasks.md 7일 이상 stale 검증 (H10 강화)
REMAINING="$MEMORY_DIR/project_remaining_tasks.md"
if [ -f "$REMAINING" ]; then
  REMAINING_DAYS=$(( ( $(date +%s) - $(stat -f "%m" "$REMAINING") ) / 86400 ))
  if [ "$REMAINING_DAYS" -gt 7 ]; then
    echo ""
    echo "⚠️ [ProjectGrimoire] WARN: project_remaining_tasks.md $REMAINING_DAYS일 stale (7일 임계 초과)"
    echo "   현재 우선순위가 시점 정합한지 검토 권장."
    echo ""
  fi
fi

# 정상 종료
if [ "$HAS_TODAY_COMMITS" = false ]; then
  echo "✅ [ProjectGrimoire] 오늘 커밋 없음. 메모리 갱신 불필요. 종료 가능."
elif [ "$MEMORY_TODAY" = "$TODAY" ]; then
  echo "✅ [ProjectGrimoire] 메모리 오늘 갱신 정합. 종료 가능."
fi

exit 0
