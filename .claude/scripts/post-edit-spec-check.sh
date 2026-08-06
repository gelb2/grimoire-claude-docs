#!/bin/sh
# post-edit-spec-check.sh — PostToolUse hook (matcher: Write|Edit)
#
# 동작:
# 1) stdin JSON 또는 $1 인자에서 편집 파일 경로 추출
# 2) 다음 화이트리스트 경로면 .spec.ts 동반 존재 여부 확인:
#    - grimoire-server/src/application/**/*.usecase.ts
#    - grimoire-server/src/lib/**/*.ts (단 *.spec.ts, *.d.ts, index.ts 제외)
#    - grimoire-server/src/adapter/**/*.ts (단 *.spec.ts, *.d.ts, index.ts, dto/ 제외)
#    - grimoire-web/src/features/**/*.{ts,tsx} (단 *.test.ts(x), *.stories.tsx, types/, index.ts(x) 제외)
# 3) 대응 spec(.spec.ts 또는 .test.ts) 파일이 없으면 stderr 경고
# 4) 화이트리스트 외 또는 spec 존재 시 조용히 exit 0
# 5) Claude 흐름 차단 안 함 (exit 0 유지)
#
# CLAUDE.md §2 "새 UseCase/서비스/파서 생성 시 반드시 .spec.ts 함께 작성" 규칙의 sensor화
# Fowler "Shift Left" — Edit 직후가 가장 싼 단계

set +e

FILE_PATH="${1:-}"

# stdin JSON 시도
if [ -z "$FILE_PATH" ] && [ ! -t 0 ]; then
  STDIN_JSON=$(cat 2>/dev/null)
  if [ -n "$STDIN_JSON" ]; then
    export STDIN_JSON
    FILE_PATH=$(python3 -c "
import json, os, sys
try:
    d = json.loads(os.environ.get('STDIN_JSON','') or '{}')
    print((d.get('tool_input') or {}).get('file_path') or '', end='')
except Exception:
    pass
" 2>/dev/null)
  fi
fi

[ -z "$FILE_PATH" ] && exit 0

# 1) 화이트리스트 경로 매칭
case "$FILE_PATH" in
  */grimoire-server/src/application/*.usecase.ts) ;;
  */grimoire-server/src/lib/*.ts) ;;
  */grimoire-server/src/adapter/*.ts) ;;
  */grimoire-web/src/features/*.ts|*/grimoire-web/src/features/*.tsx) ;;
  *) exit 0 ;;
esac

# 2) 예외 패턴 (이미 spec, type 선언, barrel export, fixture, dto 등)
case "$FILE_PATH" in
  *.spec.ts|*.spec.tsx|*.test.ts|*.test.tsx) exit 0 ;;
  *.d.ts) exit 0 ;;
  */index.ts|*/index.tsx) exit 0 ;;
  *.stories.tsx|*.stories.ts) exit 0 ;;
  */types/*) exit 0 ;;
  */dto/*) exit 0 ;;
  */__mocks__/*|*/__fixtures__/*) exit 0 ;;
esac

# 3) 대응 spec/test 파일 경로 후보
DIR=$(dirname "$FILE_PATH")
BASE=$(basename "$FILE_PATH")
STEM="${BASE%.*}"
EXT="${BASE##*.}"

# server는 .spec.ts, web은 .test.ts(x) 또는 .spec.ts(x) 둘 다 인정
SPEC_CANDIDATES="$DIR/$STEM.spec.$EXT $DIR/$STEM.test.$EXT $DIR/$STEM.spec.ts $DIR/$STEM.test.ts"

FOUND=0
for cand in $SPEC_CANDIDATES; do
  if [ -f "$cand" ]; then
    FOUND=1
    break
  fi
done

# sensor-log 적재 — orchestration ratio 정확도 향상 (FOUND=1=PASS, 0=WARN)
SENSOR_LOG="/Users/sokol/Git/ProjectGrimoire/.claude/scripts/sensor-log.sh"
if [ -x "$SENSOR_LOG" ]; then
  RC=$([ "$FOUND" -eq 1 ] && echo 0 || echo 2)
  bash "$SENSOR_LOG" "post-edit-spec-check" "$RC" "found=$FOUND file=$FILE_PATH" 2>/dev/null || true
fi

if [ "$FOUND" -eq 0 ]; then
  {
    echo "[post-edit-spec-check] 경고: $FILE_PATH 에 대응하는 spec/test 파일이 없습니다."
    echo "  CLAUDE.md §2 \"새 UseCase/서비스/파서 생성 시 반드시 .spec.ts 함께 작성\" 규칙 참조."
    echo "  기대 위치 후보:"
    for cand in $SPEC_CANDIDATES; do
      echo "    - $cand"
    done
    echo "  (이 경고는 차단이 아닌 알림. 작업 흐름 계속 진행 가능)"
  } >&2
fi

exit 0
