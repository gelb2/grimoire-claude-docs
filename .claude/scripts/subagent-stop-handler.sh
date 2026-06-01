#!/usr/bin/env bash
# subagent-stop-handler.sh — SubagentStop hook (2026-05-02 묶음 N NEW-13 신설)
#
# 동기 (HARNESS §8 미도입 항목 + §15.7.3.2 측정 한계):
#   sensor-orchestration-ratio jsonl 박제가 다음 세션 진입 시까지 지연됨.
#   본 hook은 subagent (Task tool) 종료 직후 즉시 ratio 갱신 + sensor-log 적재.
#   책 Ch 16 패턴 1 KPI를 사후 측정에서 실시간 측정으로 진화.
#
# Anthropic 명세: SubagentStop hook은 차단 불가, audit/observability만.
#   stdin payload 공통 필드: session_id / transcript_path / stop_hook_active / hook_event_name.
#   ⚠️ subagent_type 는 SubagentStop payload 표준 필드가 아님 → 종전 d.get('subagent_type') 가
#      항상 None 이라 type=unknown 80/80 고정 (2026-06-01 실측, sensor-hits.jsonl).
#
# 2026-06-01 type=unknown 정정:
#   SubagentStop payload 에 subagent_type 가 직접 오면 그대로 사용(향후 명세 변경 대비).
#   없으면 → transcript_path(에이전트 transcript = {uuid}/subagents/agent-XXXX.jsonl)에서 agent id 추출
#   → 짝 agent-XXXX.meta.json 의 agentType 으로 식별 (meta.json 은 전 프로젝트 공통 구조로 실증).
#   transcript_path 도 못 얻으면 → 방금 종료분일 개연이 높은 "최신 mtime meta.json" fallback.
#   끝까지 불가 시에만 정직하게 'unknown' (추정 금지).
#   1회성 진단: payload 원본을 .claude/state/subagent-payload-debug.jsonl 에 append(키 실증용, 최대 50줄 유지).

set +u

INPUT_JSON=$(cat 2>/dev/null)
ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
STATE_DIR="$ROOT/.claude/state"
PROJ_DIR="$HOME/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire"
mkdir -p "$STATE_DIR"

# payload 진단 박제 (실측 키 입증용 — 추정 대신 raw 보존, 50줄 ring)
DEBUG_FILE="$STATE_DIR/subagent-payload-debug.jsonl"
if [ -n "$INPUT_JSON" ]; then
  printf '%s\n' "$INPUT_JSON" >> "$DEBUG_FILE" 2>/dev/null || true
  # 50줄 초과 시 tail 유지
  if [ "$(wc -l < "$DEBUG_FILE" 2>/dev/null || echo 0)" -gt 50 ]; then
    tail -50 "$DEBUG_FILE" > "$DEBUG_FILE.tmp" 2>/dev/null && mv "$DEBUG_FILE.tmp" "$DEBUG_FILE" 2>/dev/null || true
  fi
fi

# subagent_type 식별: payload 직접 → transcript_path→meta.json → 최신 mtime meta.json fallback
SUBAGENT_TYPE=$(PROJ_DIR="$PROJ_DIR" python3 -c "
import json, sys, os, glob

raw = sys.stdin.read()
proj = os.environ.get('PROJ_DIR', '')

def from_meta_path(meta_path):
    try:
        with open(meta_path) as f:
            return json.load(f).get('agentType') or None
    except Exception:
        return None

result = None
try:
    d = json.loads(raw)
except Exception:
    d = {}

# 1) payload 직접 (표준 아님이나 향후 대비)
if isinstance(d, dict):
    for k in ('subagent_type', 'agentType', 'agent', 'subagentType'):
        v = d.get(k)
        if v:
            result = v
            break

# 2) transcript_path 기반: agent transcript → 짝 meta.json
if not result and isinstance(d, dict):
    tp = d.get('transcript_path') or d.get('transcriptPath') or ''
    if tp and tp.endswith('.jsonl') and '/subagents/' in tp:
        mp = tp[:-len('.jsonl')] + '.meta.json'
        if os.path.exists(mp):
            result = from_meta_path(mp)

# 3) fallback: 가장 최근 mtime meta.json (방금 종료분 개연)
if not result and proj:
    metas = glob.glob(proj + '/*/subagents/agent-*.meta.json')
    if metas:
        newest = max(metas, key=lambda p: os.path.getmtime(p))
        result = from_meta_path(newest)

print(result if result else 'unknown')
" <<< "$INPUT_JSON" 2>/dev/null)

[ -z "$SUBAGENT_TYPE" ] && SUBAGENT_TYPE="unknown"

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
