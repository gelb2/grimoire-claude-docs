#!/bin/bash
# 메모리 신선도 검증 스크립트 — ProjectGrimoire
# SessionStart 훅에서 자동 호출. git 최신 커밋 vs 메모리 최종 수정 비교.

MEMORY_DIR="$HOME/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/memory"
PROJECT_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire"
REPOS="grimoire-server grimoire-web grimoire-ios"

if [ ! -d "$MEMORY_DIR" ]; then
  echo "⚠️  메모리 디렉토리가 없습니다: $MEMORY_DIR"
  exit 0
fi

# project_state 또는 project_session 파일 중 가장 최신 것
LATEST_MEMORY_FILE=$(ls -t "$MEMORY_DIR"/project_state_*.md "$MEMORY_DIR"/project_session_*.md "$MEMORY_DIR"/project_remaining_tasks.md 2>/dev/null | head -1)
if [ -z "$LATEST_MEMORY_FILE" ]; then
  echo "⚠️  project_state/session 메모리 파일이 하나도 없습니다."
  exit 0
fi
MEMORY_EPOCH=$(stat -f "%m" "$LATEST_MEMORY_FILE" 2>/dev/null)
MEMORY_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$LATEST_MEMORY_FILE" 2>/dev/null)
MEMORY_NAME=$(basename "$LATEST_MEMORY_FILE")

MAX_COMMIT_EPOCH=0
MAX_COMMIT_REPO=""
MAX_COMMIT_DATE=""

for REPO in $REPOS; do
  REPO_PATH="$PROJECT_DIR/$REPO"
  if [ -d "$REPO_PATH/.git" ]; then
    COMMIT_DATE=$(cd "$REPO_PATH" && git log -1 --format="%ai" develop 2>/dev/null || git log -1 --format="%ai" 2>/dev/null)
    if [ -n "$COMMIT_DATE" ]; then
      COMMIT_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$COMMIT_DATE" "+%s" 2>/dev/null)
      if [ -n "$COMMIT_EPOCH" ] && [ "$COMMIT_EPOCH" -gt "$MAX_COMMIT_EPOCH" ]; then
        MAX_COMMIT_EPOCH=$COMMIT_EPOCH
        MAX_COMMIT_REPO=$REPO
        MAX_COMMIT_DATE=$(echo "$COMMIT_DATE" | cut -d' ' -f1,2 | cut -d':' -f1,2)
      fi
    fi
  fi
done

if [ "$MAX_COMMIT_EPOCH" -eq 0 ]; then
  echo "ℹ️  git 레포가 없거나 커밋이 없습니다."
  exit 0
fi

GAP=$((MAX_COMMIT_EPOCH - MEMORY_EPOCH))

if [ "$GAP" -gt 3600 ]; then
  HOURS=$((GAP / 3600))
  echo ""
  echo "🚨🚨🚨 [ProjectGrimoire] 메모리 경고 🚨🚨🚨"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "메모리 최종 갱신: $MEMORY_NAME ($MEMORY_DATE)"
  echo "최신 git 커밋:   $MAX_COMMIT_REPO ($MAX_COMMIT_DATE)"
  echo "격차: 약 ${HOURS}시간 뒤처짐"
  echo ""
  echo "이전 세션이 메모리 저장을 누락했을 가능성 높음."
  echo ""
  echo "▶ 복구 절차 (사용자 요청 전에 먼저 실행):"
  echo "  1. git log --oneline -10 develop 으로 누락된 커밋 확인"
  echo "  2. CHANGELOG.md 읽어서 작업 내역 파악"
  echo "  3. project_session_YYYY_MM_DD.md 메모리 파일 Write 도구로 작성"
  echo "  4. MEMORY.md 인덱스 갱신"
  echo "  5. 사용자에게 '이전 세션 메모리 누락 감지, 복구 완료' 보고"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
elif [ "$GAP" -gt 0 ]; then
  echo "✅ [ProjectGrimoire] 메모리 상태 양호 (최신 커밋 대비 ${GAP}초 차이, $MEMORY_NAME)"
else
  echo "✅ [ProjectGrimoire] 메모리가 최신 상태입니다 ($MEMORY_NAME)"
fi
