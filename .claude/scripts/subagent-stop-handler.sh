#!/usr/bin/env bash
# subagent-stop-handler.sh — SubagentStop hook (2026-05-02 묶음 N NEW-13 신설)
#
# 동기 (HARNESS §8 미도입 항목 + §15.7.3.2 측정 한계):
#   sensor-orchestration-ratio jsonl 박제가 다음 세션 진입 시까지 지연됨.
#   본 hook은 subagent (Task tool) 종료 직후 즉시 ratio 갱신 + sensor-log 적재.
#   책 Ch 16 패턴 1 KPI를 사후 측정에서 실시간 측정으로 진화.
#
# Anthropic 명세: SubagentStop hook은 차단 불가, audit/observability만.
# stdin: subagent metadata JSON (subagent_type / subagent_id / duration 등)

set +u

INPUT_JSON=$(cat 2>/dev/null)
ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"

# subagent_type 추출 (JSON 파싱, 실패 시 unknown)
SUBAGENT_TYPE=$(echo "$INPUT_JSON" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('subagent_type', d.get('agent', 'unknown')))
except Exception:
    print('unknown')
" 2>/dev/null)

# 1) sensor-orchestration-ratio 즉시 갱신 (quiet 모드)
if [ -x "$ROOT/.claude/scripts/sensor-orchestration-ratio.sh" ]; then
  bash "$ROOT/.claude/scripts/sensor-orchestration-ratio.sh" --quiet > /dev/null 2>&1 || true
fi

# 2) sensor-log에 SubagentStop 이벤트 박제 (sensor-hits.jsonl)
if [ -x "$ROOT/.claude/scripts/sensor-log.sh" ]; then
  bash "$ROOT/.claude/scripts/sensor-log.sh" "subagent-stop" PASS "type=$SUBAGENT_TYPE" 2>/dev/null || true
fi

# stderr에 audit 표시 (Claude Code가 출력 수집)
echo "[subagent-stop] $SUBAGENT_TYPE 종료 → orchestration-ratio 갱신 + sensor-log 박제" >&2

exit 0
