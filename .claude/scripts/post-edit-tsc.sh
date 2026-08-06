#!/bin/sh
# post-edit-tsc.sh — Edit/Write 도구 호출 후 자동 TypeScript 체크
#
# 호출 방식 (둘 다 지원):
#   1) stdin JSON: Claude Code hook 기본 방식
#      echo '{"tool_input":{"file_path":"..."}}' | bash post-edit-tsc.sh
#   2) 인자: bash post-edit-tsc.sh "$CLAUDE_TOOL_INPUT_file_path" (fallback)
#
# 정책:
# - .ts/.tsx/.cts/.mts 파일만 대상. 그 외는 조용히 exit 0
# - 편집 파일이 grimoire-server/ 이면 server 레포에서, grimoire-web/ 이면 web 레포에서 tsc 실행
# - 둘 다 아니면 조용히 exit 0 (루트 .claude 설정 파일 등)
# - tsc 실패해도 exit 0 유지 (Claude 흐름 차단하지 않음, stderr에 경고만 출력)
# - tsc 출력은 마지막 20줄만 표시해 컨텍스트 폭주 방지

set +e

FILE_PATH="${1:-}"

# stdin JSON이 있으면 파싱 시도 (Claude Code 공식 hook 방식)
if [ -z "$FILE_PATH" ] && [ ! -t 0 ]; then
  STDIN_JSON=$(cat 2>/dev/null)
  if [ -n "$STDIN_JSON" ]; then
    FILE_PATH=$(printf '%s' "$STDIN_JSON" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    ti = d.get('tool_input') or {}
    print(ti.get('file_path') or '', end='')
except Exception:
    pass
" 2>/dev/null)
  fi
fi

[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  *.ts|*.tsx|*.cts|*.mts) ;;
  *) exit 0 ;;
esac

REPO=""
case "$FILE_PATH" in
  */grimoire-server/*)
    REPO="/Users/sokol/Git/ProjectGrimoire/grimoire-server"
    ;;
  */grimoire-web/*)
    REPO="/Users/sokol/Git/ProjectGrimoire/grimoire-web"
    ;;
  *) exit 0 ;;
esac

[ ! -d "$REPO" ] && exit 0

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

OUTPUT=$(cd "$REPO" && npx tsc --noEmit 2>&1)
RC=$?

# sensor-log 적재 — 메인 직접 작업의 hit-rate 측정 + orchestration ratio 정확도 향상
# REPO 명을 EXTRA로 박제 (server vs web 분포 분석용)
SENSOR_LOG="/Users/sokol/Git/ProjectGrimoire/.claude/scripts/sensor-log.sh"
if [ -x "$SENSOR_LOG" ]; then
  REPO_NAME=$(basename "$REPO")
  bash "$SENSOR_LOG" "post-edit-tsc" "$RC" "repo=$REPO_NAME file=$FILE_PATH" 2>/dev/null || true
fi

if [ "$RC" -ne 0 ]; then
  {
    echo "[post-edit-tsc] $REPO: tsc 실패 (exit $RC). 최근 20줄:"
    echo "$OUTPUT" | tail -n 20
  } >&2
fi

exit 0
