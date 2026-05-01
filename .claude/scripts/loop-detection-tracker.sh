#!/usr/bin/env bash
# loop-detection-tracker.sh — Edit/Write 횟수 파일별 누적 박제 (책 Ch 21 LangChain LoopDetectionMiddleware 차용)
#
# 동기 (책 Ch 21 Correct 기둥 강화 + 안티패턴 #6 둠 루프 방지):
#   - LangChain LoopDetectionMiddleware 정본 패턴: MAX_EDITS_PER_FILE = 5
#   - 5회 초과 시 ALERT — 같은 파일 반복 수정 = 가설 분리 실패 신호
#   - production-bug-triage / systematic-debugging skill로 escalation 유도
#
# 호출: PostToolUse (Edit|Write matcher)
# stdin: JSON {tool_name, tool_input: {file_path, ...}}
# 박제: .claude/state/loop-detection.jsonl
#
# 임계값:
#   - 정상: 1~4회
#   - WARN: 5회 (책 권장 임계)
#   - FAIL: 6회 이상 — 가설 분리 실패 의심

set +u

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
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
LOG_FILE = '/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/state/loop-detection.jsonl'
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
