#!/bin/bash
# PreCompact 훅 — ProjectGrimoire 컨텍스트 압축 직전 (2026-05-02 묶음 O NEW-15 강화)
#
# 동기:
#   장시간 세션 → 컨텍스트 압축 시점에 메모리 박제 안 됐으면 작업 손실 위험.
#   stop-memory-guard와 동일 패턴 (H10) + PreCompact 시점 박제.
#
# 강화 사항 (NEW-15):
#   - grimoire-ios 제거 (stop-memory-guard와 통일)
#   - claude-docs 자체 commit 포함
#   - MEMORY.md 인덱스 오늘 박제 검증
#   - 컨텍스트 압축 시점 sensor-log 박제

MEMORY_DIR="$HOME/.claude/projects/-Users-sokol-Git-ProjectGrimoire/memory"
PROJECT_DIR="/Users/sokol/Git/ProjectGrimoire"
REPOS="grimoire-server grimoire-web"

TODAY=$(date "+%Y-%m-%d")
NOW_TIME=$(date "+%H:%M")
TODAY_COMPACT="${TODAY//-/}"

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

# claude-docs 워크스페이스 루트 .git 별도 검증 (H10 패턴)
if [ -d "$PROJECT_DIR/.git" ]; then
  COUNT=$(cd "$PROJECT_DIR" && git log --since="$TODAY 00:00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 0 ]; then
    HAS_TODAY_COMMITS=true
  fi
fi

# [2] 가장 최신 메모리 파일 + MEMORY.md 인덱스 박제 검증
LATEST_MEMORY=$(ls -t "$MEMORY_DIR"/project_session_*.md "$MEMORY_DIR"/project_state_*.md 2>/dev/null | head -1)
MEMORY_TODAY="?"
if [ -n "$LATEST_MEMORY" ]; then
  MEMORY_TODAY=$(stat -f "%Sm" -t "%Y-%m-%d" "$LATEST_MEMORY" 2>/dev/null)
fi

INDEX_HAS_TODAY=false
MEMORY_INDEX="$MEMORY_DIR/MEMORY.md"
if [ -f "$MEMORY_INDEX" ] && grep -q "$TODAY_COMPACT" "$MEMORY_INDEX" 2>/dev/null; then
  INDEX_HAS_TODAY=true
fi

# [3] 알림
if [ "$HAS_TODAY_COMMITS" = true ]; then
  echo ""
  echo "🚨 [Grimoire] 컨텍스트 압축 감지 ($NOW_TIME, $TODAY)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "오늘 commit 있음. 메모리 박제 상태 점검:"
  echo ""

  if [ "$MEMORY_TODAY" != "$TODAY" ]; then
    echo "  ❌ 오늘 메모리 파일 없음 (마지막 갱신: $MEMORY_TODAY)"
    echo "     → project_session_${TODAY_COMPACT}*.md 즉시 작성 필요"
  else
    echo "  ✅ 오늘 메모리 파일 존재 ($(basename "$LATEST_MEMORY"))"
  fi

  if [ "$INDEX_HAS_TODAY" = "false" ]; then
    echo "  ❌ MEMORY.md 인덱스에 오늘($TODAY) 박제 없음"
    echo "     → MEMORY.md에 오늘 세션 1줄 추가 필요"
  else
    echo "  ✅ MEMORY.md 인덱스에 오늘 박제 확인"
  fi

  echo ""
  echo "▶ 압축 직전 즉시 Write 도구로 박제:"
  echo "  - project_session_${TODAY_COMPACT}*.md (작업 요약 + commit hash + 남은 작업)"
  echo "  - MEMORY.md 인덱스 1줄 추가"
  echo "  - project_remaining_tasks.md 현행화"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# [4] 압축 시점 sensor-log 박제 (NEW-15 추가 — 운영 데이터 누적)
SENSOR_LOG="$PROJECT_DIR/.claude/scripts/sensor-log.sh"
if [ -x "$SENSOR_LOG" ]; then
  bash "$SENSOR_LOG" "pre-compact" "PASS" "today_commits=$HAS_TODAY_COMMITS memory_today=$MEMORY_TODAY index_today=$INDEX_HAS_TODAY" 2>/dev/null || true
fi

exit 0
