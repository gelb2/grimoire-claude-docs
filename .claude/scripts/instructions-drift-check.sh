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
# 검증 항목 (§17 분할 정본 4파일 — 2026-05-02 묶음 K L1):
#   - CLAUDE.md (root) 존재 + ≤ 80줄
#   - .claude/AGENTS.md 존재 + ≤ 200줄
#   - docs/AGENTS.md 존재 + ≤ 300줄
#   - .githooks/AGENTS.md 존재 + ≤ 200줄
#
# Fowler "Harness drift" 실패 모드 자동 탐지 (HARNESS §4)

set +e

# 2026-06-01 hang 정정 — 종전 `INPUT_JSON=$(cat)` 는 stdin 이 닫히지 않은 호출자
#   (예: grade.py subprocess.run 가 stdin 미지정 → 부모 fd 상속, eval 전체 run)에서
#   EOF 를 무한 대기 → 300s timeout → grade.py 사망 후 자식 bash 고아(PPID=1) 영생 누적.
#   InstructionsLoaded hook 정상 경로(JSON 파이프 전달)는 데이터가 즉시 도착하므로
#   `read -t` 타임아웃에 영향 없음. tty 직접 실행 / stdin 無 호출은 빈 입력으로 즉시 진행.
INPUT_JSON=""
if [ ! -t 0 ]; then
  # 비-tty stdin: hook JSON 은 즉시 도착. 데이터 없으면 1s 후 빈 입력으로 진행 (무한대기 차단).
  IFS= read -r -d '' -t 1 INPUT_JSON 2>/dev/null || true
fi
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
ROOT_CLAUDE = "/Users/sokol/Git/ProjectGrimoire/CLAUDE.md"
if file_path != ROOT_CLAUDE:
    sys.exit(0)

# §14 본문은 research로 이동했으므로 CLAUDE.md §14 자체에 N개 표기 거의 없음.
# 대신 research/HARNESS_ENGINEERING.md §14의 표기와 실측을 비교.
RESEARCH = "/Users/sokol/Git/ProjectGrimoire/research/HARNESS_ENGINEERING.md"
if not Path(RESEARCH).exists():
    sys.exit(0)

content = Path(RESEARCH).read_text()

# 실측
PROJECT = "/Users/sokol/Git/ProjectGrimoire"
agents_actual = len(glob.glob(f"{PROJECT}/.claude/agents/*.md"))
skills_actual = len(glob.glob(f"{PROJECT}/.claude/skills/*/SKILL.md"))
sensors_actual = len(glob.glob(f"{PROJECT}/.claude/scripts/sensor-*.sh"))
knowledge_actual = len(glob.glob(f"{PROJECT}/.claude/knowledge/*.md"))
commands_actual = len(glob.glob(f"{PROJECT}/.claude/commands/*.md"))

# settings.json hook 이벤트 수 + 등록 스크립트 수 (unique .sh 파일명)
settings_path = f"{PROJECT}/.claude/settings.json"
hook_events = 0
hook_scripts = 0
if Path(settings_path).exists():
    try:
        s = json.loads(Path(settings_path).read_text())
        hooks_obj = s.get('hooks', {})
        hook_events = len(hooks_obj.keys())
        # 등록 스크립트 실측: 모든 이벤트의 command 내 .sh 파일명을 basename으로 unique 카운트
        script_names = set()
        for ev_entries in hooks_obj.values():
            for entry in ev_entries:
                for h in entry.get('hooks', []):
                    cmd = h.get('command', '')
                    for tok in re.findall(r'[A-Za-z0-9._/-]+\.sh', cmd):
                        script_names.add(tok.rsplit('/', 1)[-1])
        hook_scripts = len(script_names)
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

# Hooks 표기는 "14.3 Hooks N 이벤트 M 스크립트" 형태 — 이벤트 수 + 스크립트 수 동시 추출
hook_events_doc = None
hook_scripts_doc = None
m_hooks = re.search(r'14\.3\s*Hooks\s*(\d+)\s*이벤트\s*(\d+)\s*스크립트', content)
if m_hooks:
    try:
        hook_events_doc = int(m_hooks.group(1))
        hook_scripts_doc = int(m_hooks.group(2))
    except (ValueError, IndexError):
        pass

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
if hook_events_doc is not None and hook_events_doc != hook_events:
    drifts.append(f"Hooks 이벤트: 문서 {hook_events_doc}개 vs 실측 {hook_events}개")
if hook_scripts_doc is not None and hook_scripts_doc != hook_scripts:
    drifts.append(f"Hooks 스크립트: 문서 {hook_scripts_doc}개 vs 실측 {hook_scripts}개")

# §17 분할 정본 4파일 검증 (2026-05-02 묶음 K L1)
SPLIT_FILES = [
    (PROJECT + "/CLAUDE.md", 80, "CLAUDE.md (root)"),
    (PROJECT + "/.claude/AGENTS.md", 200, ".claude/AGENTS.md"),
    (PROJECT + "/docs/AGENTS.md", 300, "docs/AGENTS.md"),
    (PROJECT + "/.githooks/AGENTS.md", 200, ".githooks/AGENTS.md"),
]
for path, threshold, label in SPLIT_FILES:
    if not Path(path).exists():
        drifts.append(f"§17 분할 정본 누락: {label}")
    else:
        try:
            with open(path) as f:
                lines = sum(1 for _ in f)
            if lines > threshold:
                drifts.append(f"§17 {label}: {lines}줄 > {threshold} 임계 (책 Ch 08 60-line 위반 위험)")
        except Exception:
            pass

# 평행정본(HTML 맵) 카운트 사각 봉합 (2026-06-26 문서감사 2차 재발방지)
# HARNESS_MAP.html 헤드라인 subtitle 의 하드 카운트가 실측과 어긋나면 WARN.
# (본문 Mermaid 노드 라벨은 시각 보조라 면제 — 헤드라인만 §14 동기화 대상으로 강제)
HMAP = f"{PROJECT}/HARNESS_MAP.html"
if Path(HMAP).exists():
    try:
        htext = Path(HMAP).read_text()
        # subtitle 1줄만 대상 (class="subtitle")
        m_sub = re.search(r'<p class="subtitle">(.*?)</p>', htext, re.S)
        sub = m_sub.group(1) if m_sub else ""
        def _hn(pat):
            mm = re.search(pat, sub)
            return int(mm.group(1)) if mm else None
        hmap_agents = _hn(r'(\d+)\s*grimoire-\*\s*agent')
        hmap_sensors = _hn(r'(\d+)\s*Sensors')
        # "26 Skills 현역" — 현역 카운트(§14.2 헤드라인 표기 기준)와 대조
        hmap_skills = _hn(r'(\d+)\s*Skills')
        if hmap_agents is not None and hmap_agents != agents_actual:
            drifts.append(f"평행정본 HARNESS_MAP.html: agent {hmap_agents} vs 실측 {agents_actual} (헤드라인 §14.1 동기화 필요)")
        if hmap_sensors is not None and hmap_sensors != sensors_actual:
            drifts.append(f"평행정본 HARNESS_MAP.html: Sensors {hmap_sensors} vs 실측 {sensors_actual} (헤드라인 §14.4 동기화 필요)")
        if hmap_skills is not None and hmap_skills != skills_actual:
            drifts.append(f"평행정본 HARNESS_MAP.html: Skills(현역) {hmap_skills} vs 실측 {skills_actual} (헤드라인 §14.2 동기화 필요)")
    except Exception:
        pass

if drifts:
    print(f"[instructions-drift-check] CLAUDE.md 로드 ({load_reason}) — research/HARNESS_ENGINEERING.md §14 또는 §17 drift 발견:", file=sys.stderr)
    for d in drifts:
        print(f"  ⚠️ {d}", file=sys.stderr)
    print(f"  → research §14 갱신 (update-harness-inventory --apply) 또는 §17 분할 정본 검토 권장", file=sys.stderr)

sys.exit(0)
PYEOF

exit 0
