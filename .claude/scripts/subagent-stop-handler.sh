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
#
# 2026-06-02 P2#4 실측 정정 (subagent-payload-debug.jsonl 7건 raw 확인 — 추정 폐기):
#   실제 SubagentStop payload 는 다음 키를 직접 싣는다(이 프로젝트/현 Claude Code 버전):
#     - agent_type            : "grimoire-harness" / "grimoire-qa" / "grimoire-verifier" 등 (← 정답, 직접 사용)
#     - agent_id              : "ae86f1695c27cfa21" 등
#     - agent_transcript_path : …/{uuid}/subagents/agent-XXXX.jsonl  (서브에이전트 transcript)
#     - transcript_path       : …/{uuid}.jsonl                       (*메인* 세션 transcript — /subagents/ 없음)
#   종전 코드는 step-1 에서 snake_case `agent_type` 를 빠뜨려(‘subagent_type’만 봄) 항상 실패 →
#   step-2 도 메인 transcript_path 라 /subagents/ 미포함으로 실패 → step-3(최신 mtime meta.json)
#   fallback 으로 떨어져, 7 payload 중 3건(qa/verifier)을 harness 로 오식별. 'unknown' 자체는
#   해소됐었지만 *오답*을 내고 있었던 셈. → step-1 에 agent_type, step-2 에 agent_transcript_path
#   추가로 7/7 직접·정확 식별(fallback 0).
#
# 식별 우선순위(현행): ① payload.agent_type 직접 → ② agent_transcript_path → 짝 .meta.json 의 agentType
#   → ③ 최신 mtime meta.json fallback → 끝까지 불가 시에만 정직하게 'unknown'(추정 금지).
#   진단 박제: payload 원본을 .claude/state/subagent-payload-debug.jsonl 에 append(키 실증용, 최대 50줄 ring).

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

# 1) payload 직접
#    ⚠️ 2026-06-02 P2#4 실측(subagent-payload-debug.jsonl 7건): 실제 SubagentStop payload 는
#    snake_case `agent_type` 로 에이전트 타입을 직접 실어 보낸다(예: "grimoire-harness"/"grimoire-qa"/
#    "grimoire-verifier"). 종전 키 목록에 `agent_type` 가 빠져 step-1 이 항상 실패 → step-3
#    (최신 mtime fallback)로 떨어져 7건 중 3건 오식별(qa/verifier 를 harness 로 라벨)되던 결함.
#    `agent_type` 를 선두에 추가하면 7/7 step-1 직접 식별(fallback 0, 오식별 0). 나머지 키는 향후 대비 유지.
if isinstance(d, dict):
    for k in ('agent_type', 'subagent_type', 'agentType', 'agent', 'subagentType'):
        v = d.get(k)
        if v:
            result = v
            break

# 2) transcript_path 기반: agent transcript → 짝 meta.json
#    실측: payload 의 `transcript_path` 는 *메인* 세션 jsonl(…/{uuid}.jsonl, /subagents/ 없음)이라
#    여기에 안 걸린다. 서브에이전트 transcript 는 별도 키 `agent_transcript_path`
#    (…/{uuid}/subagents/agent-XXXX.jsonl)로 온다 → 이를 선두 후보로 추가(step-1 실패 시의 견고한 2차).
if not result and isinstance(d, dict):
    tp = d.get('agent_transcript_path') or d.get('transcript_path') or d.get('transcriptPath') or ''
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
