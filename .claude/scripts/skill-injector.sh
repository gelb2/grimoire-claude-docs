#!/bin/sh
# skill-injector.sh — UserPromptSubmit hook
#
# 동작:
# 1) stdin으로 전달된 Claude Code hook JSON에서 사용자 프롬프트 추출
# 2) .claude/skills/*/SKILL.md 의 frontmatter에서 triggers: 목록 파싱
# 3) 프롬프트가 트리거 키워드 매칭되면 해당 SKILL.md 본문을
#    hookSpecificOutput.additionalContext JSON으로 stdout 출력
# 4) 세션 내 중복 주입 방지 (.claude/state/skill-sessions.json)
#
# 참조 패턴: oh-my-claudecode skill-injector
# Fowler "sensors optimised for LLM consumption" 원칙 준수

set +e

SKILLS_DIR="/Users/sokol/Git/ProjectGrimoire/.claude/skills"
STATE_DIR="/Users/sokol/Git/ProjectGrimoire/.claude/state"
STATE_FILE="$STATE_DIR/skill-sessions.json"

mkdir -p "$STATE_DIR"
[ ! -f "$STATE_FILE" ] && echo '{}' > "$STATE_FILE"

# stdin JSON → 환경변수로 안전하게 전달
INPUT_JSON=$(cat 2>/dev/null)
[ -z "$INPUT_JSON" ] && exit 0

export INPUT_JSON SKILLS_DIR STATE_FILE

python3 - <<'PYEOF'
import json
import os
import re
import sys
import glob
from pathlib import Path

SKILLS_DIR = os.environ['SKILLS_DIR']
STATE_FILE = os.environ['STATE_FILE']
INPUT_JSON = os.environ.get('INPUT_JSON', '')

try:
    payload = json.loads(INPUT_JSON) if INPUT_JSON.strip() else {}
except Exception:
    sys.exit(0)

# Claude Code는 UserPromptSubmit에서 {"prompt": "...", "session_id": "..."} 전달
prompt_text = payload.get('prompt') or payload.get('user_prompt') or ''
session_id = payload.get('session_id') or payload.get('sessionId') or 'default'

if not prompt_text:
    sys.exit(0)

# 세션 state 로드
try:
    state = json.loads(Path(STATE_FILE).read_text() or '{}')
except Exception:
    state = {}

already_injected = set(state.get(session_id, []))

# 각 SKILL.md frontmatter 파싱
matched_skills = []
for skill_path in sorted(glob.glob(os.path.join(SKILLS_DIR, '*/SKILL.md'))):
    try:
        content = Path(skill_path).read_text()
    except Exception:
        continue

    m = re.match(r'^---\s*\n(.*?)\n---\s*\n(.*)$', content, re.DOTALL)
    if not m:
        continue
    frontmatter, body = m.group(1), m.group(2)

    name_m = re.search(r'^name:\s*(\S+)\s*$', frontmatter, re.MULTILINE)
    if not name_m:
        continue
    skill_name = name_m.group(1)

    if skill_name in already_injected:
        continue

    # triggers 블록 추출
    tb = re.search(r'^triggers:\s*\n((?:\s+-\s+.+\n?)+)', frontmatter, re.MULTILINE)
    if not tb:
        continue
    triggers = re.findall(r'^\s+-\s+"?([^"\n]+?)"?\s*$', tb.group(1), re.MULTILINE)
    triggers = [t.strip() for t in triggers if t.strip()]

    prompt_lower = prompt_text.lower()
    hit = next((t for t in triggers if t.lower() in prompt_lower), None)

    if hit:
        matched_skills.append((skill_name, hit, body.strip(), skill_path))

if not matched_skills:
    sys.exit(0)

sections = []
for name, trig, body, path in matched_skills:
    sections.append(
        f"<skill-auto-injected>\n"
        f"Skill: {name}\n"
        f"Trigger matched: \"{trig}\"\n"
        f"Source: {path}\n\n"
        f"{body}\n"
        f"</skill-auto-injected>"
    )

additional_context = (
    "아래 Skill(s)이 사용자 프롬프트의 키워드 매칭으로 자동 주입되었습니다. "
    "해당 프로토콜을 반드시 따라 응답하세요 (추측·면피 답변 금지).\n\n"
    + "\n\n---\n\n".join(sections)
)

# 세션 state 업데이트
state.setdefault(session_id, [])
for name, _, _, _ in matched_skills:
    if name not in state[session_id]:
        state[session_id].append(name)
try:
    Path(STATE_FILE).write_text(json.dumps(state, ensure_ascii=False, indent=2))
except Exception:
    pass

output = {
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": additional_context
    }
}
print(json.dumps(output, ensure_ascii=False))
PYEOF

exit 0
