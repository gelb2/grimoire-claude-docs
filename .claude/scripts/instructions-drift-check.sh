#!/usr/bin/env bash
# instructions-drift-check.sh — InstructionsLoaded hook
#
# 동작:
# 1) CLAUDE.md / .claude/rules/*.md 로드 시 발동 (Anthropic InstructionsLoaded hook)
# 2) stdin JSON에서 file_path + load_reason 추출
# 3) 루트 CLAUDE.md가 로드된 경우 §14 (멀티 에이전트 구조) 박제와 실측 비교
# 4) drift 발견 시 stderr 경고 (decision control 없음, audit 전용)
# 5) Anthropic 명세: InstructionsLoaded는 차단 불가, audit/observability만
#
# 검증 항목 (CLAUDE.md §14 표기 vs 실측):
#   - Agents N개 vs ls .claude/agents/*.md 개수
#   - Skills N개 vs ls .claude/skills/*/SKILL.md 개수
#   - Sensors N개 vs ls .claude/scripts/sensor-*.sh 개수
#   - Hooks N 이벤트 vs settings.json hook keys 개수
#
# Fowler "Harness drift" 실패 모드 자동 탐지 (HARNESS §4)

set +e

INPUT_JSON=$(cat 2>/dev/null)
[ -z "$INPUT_JSON" ] && exit 0

export INPUT_JSON

python3 - <<'PYEOF'
import json
import os
import sys
import re
import glob
from pathlib import Path

try:
    payload = json.loads(os.environ.get('INPUT_JSON', '{}'))
except Exception:
    sys.exit(0)

file_path = payload.get('file_path', '')
load_reason = payload.get('load_reason', '')
memory_type = payload.get('memory_type', '')

# 루트 CLAUDE.md만 검사 대상 (sub repo CLAUDE.md, .claude/rules/* 등은 스킵)
ROOT_CLAUDE = "/Users/sokol/Desktop/Git/ProjectGrimoire/CLAUDE.md"
if file_path != ROOT_CLAUDE:
    sys.exit(0)

# §14 본문은 research로 이동했으므로 CLAUDE.md §14 자체에 N개 표기 거의 없음.
# 대신 research/HARNESS_ENGINEERING.md §14의 표기와 실측을 비교.
RESEARCH = "/Users/sokol/Desktop/Git/ProjectGrimoire/research/HARNESS_ENGINEERING.md"
if not Path(RESEARCH).exists():
    sys.exit(0)

content = Path(RESEARCH).read_text()

# 실측
PROJECT = "/Users/sokol/Desktop/Git/ProjectGrimoire"
agents_actual = len(glob.glob(f"{PROJECT}/.claude/agents/*.md"))
skills_actual = len(glob.glob(f"{PROJECT}/.claude/skills/*/SKILL.md"))
sensors_actual = len(glob.glob(f"{PROJECT}/.claude/scripts/sensor-*.sh"))
knowledge_actual = len(glob.glob(f"{PROJECT}/.claude/knowledge/*.md"))
commands_actual = len(glob.glob(f"{PROJECT}/.claude/commands/*.md"))

# settings.json hook 이벤트 수
settings_path = f"{PROJECT}/.claude/settings.json"
hook_events = 0
if Path(settings_path).exists():
    try:
        s = json.loads(Path(settings_path).read_text())
        hook_events = len(s.get('hooks', {}).keys())
    except Exception:
        pass

# research 문서 표기 추출 (정규식)
def extract_n(pattern, text):
    """### 14.1 Agents 7개 → 7"""
    m = re.search(pattern, text)
    if m:
        try:
            return int(m.group(1))
        except (ValueError, IndexError):
            return None
    return None

agents_doc = extract_n(r'14\.1\s*Agents\s*(\d+)\s*개', content)
skills_doc = extract_n(r'14\.2\s*Skills\s*(\d+)\s*종', content)
sensors_doc = extract_n(r'14\.4\s*Sensors\s*(\d+)\s*개', content)
knowledge_doc = extract_n(r'14\.5\s*Knowledge\s*(\d+)\s*개', content)
slash_doc = extract_n(r'14\.6\s*Slash commands\s*(\d+)\s*개', content)

# drift 비교
drifts = []
if agents_doc is not None and agents_doc != agents_actual:
    drifts.append(f"Agents: 문서 {agents_doc}개 vs 실측 {agents_actual}개")
if skills_doc is not None and skills_doc != skills_actual:
    drifts.append(f"Skills: 문서 {skills_doc}종 vs 실측 {skills_actual}종")
if sensors_doc is not None and sensors_doc != sensors_actual:
    drifts.append(f"Sensors: 문서 {sensors_doc}개 vs 실측 {sensors_actual}개")
if knowledge_doc is not None and knowledge_doc != knowledge_actual:
    drifts.append(f"Knowledge: 문서 {knowledge_doc}개 vs 실측 {knowledge_actual}개")
if slash_doc is not None and slash_doc != commands_actual:
    drifts.append(f"Slash commands: 문서 {slash_doc}개 vs 실측 {commands_actual}개")

if drifts:
    print(f"[instructions-drift-check] CLAUDE.md 로드 ({load_reason}) — research/HARNESS_ENGINEERING.md §14 drift 발견:", file=sys.stderr)
    for d in drifts:
        print(f"  ⚠️ {d}", file=sys.stderr)
    print(f"  → research §14 갱신 권장 (Fowler Harness drift 실패 모드 직접 사례)", file=sys.stderr)

sys.exit(0)
PYEOF

exit 0
