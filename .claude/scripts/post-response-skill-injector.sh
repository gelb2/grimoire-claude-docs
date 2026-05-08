#!/bin/bash
# post-response-skill-injector.sh — Stop hook으로 메인 응답 매칭 (PP-6)
#
# 배경:
#   skill-injector.sh는 UserPromptSubmit hook으로 사용자 프롬프트만 매칭한다.
#   메인(Claude) 응답에 "완료/끝남/잘못/단계" 같은 autonomous trigger 키워드가
#   나타나도 verification-before-completion / socratic-self-critique / writing-plans
#   skill이 발동하지 않는다 (planner #4 발견).
#
#   본 hook은 Stop 훅에서 메인 응답을 읽어 키워드 매칭하고
#   .claude/state/post-response-skill-trigger.jsonl에 박제한다.
#   (실제 inject가 아닌 "추후 분석/eval용 트리거 박제" — Stop 훅은
#    additionalContext 주입을 지원하지 않으므로 로그형 신호만 남긴다.)
#
# 입력: stdin JSON {response/message/text: "..."}
# 출력: jsonl line + stderr 알림
# 종료: 항상 0 (비차단)

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
LOG_FILE="$ROOT/.claude/state/post-response-skill-trigger.jsonl"
mkdir -p "$(dirname "$LOG_FILE")"

INPUT=$(cat 2>/dev/null || echo "")
[ -z "$INPUT" ] && exit 0

RESPONSE_TEXT=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('response', d.get('message', d.get('text', ''))))
except Exception:
    print('')
" 2>/dev/null || echo "")

[ -z "$RESPONSE_TEXT" ] && exit 0

TRIGGERED=()
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# autonomous skill 키워드 매칭 (한국어 + 영어)
echo "$RESPONSE_TEXT" | grep -qiE "완료(됐|했|함|되었|하였)|끝(났|남)|다\s*했|done\b|completed?\b|finished\b" \
  && TRIGGERED+=("verification-before-completion")
echo "$RESPONSE_TEXT" | grep -qiE "(틀렸|잘못|실수|수정 필요|재검토|미스)" \
  && TRIGGERED+=("socratic-self-critique")
echo "$RESPONSE_TEXT" | grep -qiE "(나눠서|단계|분할|sub-task|sub task|sub_task)" \
  && TRIGGERED+=("writing-plans")

if [ "${#TRIGGERED[@]}" -gt 0 ]; then
  SKILLS_JSON=$(printf '%s\n' "${TRIGGERED[@]}" | python3 -c "
import sys, json
print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))
")
  PREVIEW=$(echo "$RESPONSE_TEXT" | head -c 200 | python3 -c "
import sys, json
print(json.dumps(sys.stdin.read()))
")
  printf '{"ts":"%s","triggered_skills":%s,"response_preview":%s}\n' \
    "$TS" "$SKILLS_JSON" "$PREVIEW" \
    >> "$LOG_FILE"
  echo "🔔 autonomous skill 매칭: ${TRIGGERED[*]}" >&2
fi

exit 0
