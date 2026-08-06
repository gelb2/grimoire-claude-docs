#!/usr/bin/env bash
# loop-detection-tracker.sh — Edit/Write 이벤트 파일별 *기록만* (책 Ch 21 LangChain LoopDetectionMiddleware 차용)
#
# ⚠️ 역할 정직(2026-06-02 P2#3 헤더==동작 정정): 본 스크립트는 **기록(append) 전용**이다.
#   카운트·임계값 판정·ALERT(WARN/FAIL)는 *별도* sensor-loop-detection.sh 가 수행한다(분할 설계).
#   본 hook 은 어떤 경우에도 stdout 출력·차단·exit≠0 을 하지 않는다(hot Edit/Write 경로 lockout 방지).
#   종전 헤더가 "5회 초과 시 ALERT" / "FAIL: 6회 이상"이라 마치 본 tracker 가 판정하는 것처럼 적혀
#   있었으나, 실제로는 loop-detection.jsonl 에 한 줄 append 만 하고 exit 0 → 정직성 위반이라 정정.
#
# 동기 (책 Ch 21 Correct 기둥 강화 + 안티패턴 #6 둠 루프 방지):
#   - LangChain LoopDetectionMiddleware 정본 패턴: MAX_EDITS_PER_FILE = 5
#   - 같은 파일 반복 수정 = 가설 분리 실패 신호 → production-bug-triage / systematic-debugging escalation
#   - 단, 위 판정·escalation 신호는 sensor-loop-detection.sh 소관(본 파일은 raw 데이터만 공급).
#
# 호출: PostToolUse (Edit|Write matcher) — 기록만, 차단 없음
# stdin: JSON {tool_name, tool_input: {file_path, ...}}
# 박제: .claude/state/loop-detection.jsonl  (← sensor-loop-detection.sh 가 읽어 WARN/FAIL 판정)
#
# 임계값(판정은 sensor-loop-detection.sh 가 수행 — 본 tracker 는 미적용, 참고용 기재):
#   - PASS:  파일별 ≤ 4회
#   - WARN:  1개 파일 5~9회 (책 권장 임계)
#   - FAIL:  1개 파일 ≥ 10회(둠 루프 명백) 또는 3개 파일 동시 ≥ 5회(다중 가설 종속 의심)

set +u

ROOT="/Users/sokol/Git/ProjectGrimoire"
LOG_FILE="$ROOT/.claude/state/loop-detection.jsonl"
mkdir -p "$(dirname "$LOG_FILE")"

INPUT_JSON=$(cat 2>/dev/null)
[ -z "$INPUT_JSON" ] && exit 0

export INPUT_JSON

python3 <<'PYEOF'
import json, os, sys
from datetime import datetime

try:
    payload = json.loads(os.environ.get('INPUT_JSON', '{}'))
except Exception:
    sys.exit(0)

tool_name = payload.get('tool_name', '')
tool_input = payload.get('tool_input', {})
if tool_name not in ('Edit', 'Write', 'NotebookEdit'):
    sys.exit(0)

file_path = ''
if isinstance(tool_input, dict):
    file_path = tool_input.get('file_path', '') or tool_input.get('notebook_path', '')

if not file_path:
    sys.exit(0)

# 일별 누적
ts = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
today = ts[:10]

# 박제
LOG_FILE = '/Users/sokol/Git/ProjectGrimoire/.claude/state/loop-detection.jsonl'
entry = {
    'ts': ts,
    'date': today,
    'tool': tool_name,
    'file': file_path,
}
with open(LOG_FILE, 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')

sys.exit(0)
PYEOF

exit 0
