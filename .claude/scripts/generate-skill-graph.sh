#!/usr/bin/env bash
# generate-skill-graph.sh — Skills 간 상호 참조 그래프 생성 (HARNESS §10 Phase 5)
#
# 동기:
#   - 11+ skill 보유. 시간이 지나면 의존 관계 모름 → 변경 영향도 측정 불가
#   - skill A가 skill B를 Read하면 의존 (ouroboros 패턴)
#   - 본 스크립트가 의존 그래프 자동 생성 → research/SKILL_GRAPH.md 박제
#
# 출력:
#   - .claude/state/skill-graph.json — raw 데이터 (시계열 누적)
#   - research/SKILL_GRAPH.md — Mermaid 다이어그램 + 표 + 분석
#
# 사용:
#   generate-skill-graph.sh             # 그래프 생성 + research/SKILL_GRAPH.md 갱신
#   generate-skill-graph.sh --dry-run   # research 갱신 없이 stdout만

set -u

export PROJECT_ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
export SKILLS_DIR="$PROJECT_ROOT/.claude/skills"
export OUTPUT_GRAPH="$PROJECT_ROOT/.claude/state/skill-graph.json"
export OUTPUT_MD="$PROJECT_ROOT/research/SKILL_GRAPH.md"
export DRY_RUN=0

mkdir -p "$(dirname "$OUTPUT_GRAPH")"

for arg in "$@"; do
  case "$arg" in --dry-run) export DRY_RUN=1 ;; esac
done

echo "=== Skill Graph Generator ($(date +'%H:%M:%S')) ==="

# heredoc은 'PYEOF' 로 quoting → bash 변수 확장 + 백틱 해석 방지
# Python 내부에서는 os.environ로만 변수 접근
python3 <<'PYEOF'
import os, re, glob, json, sys
from datetime import datetime

PROJECT_ROOT = os.environ['PROJECT_ROOT']
SKILLS_DIR = os.environ['SKILLS_DIR']
OUTPUT_GRAPH = os.environ['OUTPUT_GRAPH']
OUTPUT_MD = os.environ['OUTPUT_MD']
DRY_RUN = os.environ['DRY_RUN'] == '1'

skill_files = sorted(glob.glob(SKILLS_DIR + "/*/SKILL.md"))
skills = {}

def parse_frontmatter(content):
    if not content.startswith('---'):
        return {}, content
    end = content.find('\n---', 3)
    if end == -1:
        return {}, content
    fm_text = content[3:end].strip()
    body = content[end+4:]

    fm = {}
    current_list_key = None
    current_list = []
    for line in fm_text.split('\n'):
        if not line.strip():
            continue
        if line.startswith('  - ') or line.startswith('- '):
            item = line.lstrip('- ').strip().strip('"\'')
            current_list.append(item)
            continue
        else:
            if current_list_key:
                fm[current_list_key] = current_list
                current_list = []
                current_list_key = None
        m = re.match(r'^([\w-]+):\s*(.*)$', line)
        if m:
            k, v = m.group(1), m.group(2).strip()
            if not v:
                current_list_key = k
                current_list = []
            else:
                fm[k] = v.strip('"\'')
    if current_list_key:
        fm[current_list_key] = current_list
    return fm, body

for fpath in skill_files:
    skill_dir_name = os.path.basename(os.path.dirname(fpath))
    try:
        with open(fpath, encoding='utf-8') as f:
            content = f.read()
        fm, body = parse_frontmatter(content)
        skills[skill_dir_name] = {
            "name": fm.get("name", skill_dir_name),
            "description": fm.get("description", "")[:120],
            "triggers": fm.get("triggers", []) if isinstance(fm.get("triggers"), list) else [],
            "allowed-tools": fm.get("allowed-tools", "Read"),
            "disable-model-invocation": fm.get("disable-model-invocation", "false") == "true",
            "argument-hint": fm.get("argument-hint", ""),
            "body": body,
            "path": fpath,
        }
    except Exception as e:
        print("WARN: " + fpath + " skip (" + str(e) + ")", file=sys.stderr)

edges = []
for src_name, src_data in skills.items():
    body = src_data["body"]
    for tgt_name, tgt_data in skills.items():
        if src_name == tgt_name:
            continue
        path_ref_a = "skills/" + tgt_name + "/"
        path_ref_b = "skills/" + tgt_name + "/SKILL.md"
        if path_ref_a in body or path_ref_b in body:
            edges.append((src_name, tgt_name, "path"))
        elif tgt_name in body or tgt_data["name"] in body:
            edges.append((src_name, tgt_name, "mention"))

manual_only = [n for n, d in skills.items() if d["disable-model-invocation"]]
auto_trigger = [n for n, d in skills.items() if not d["disable-model-invocation"] and d["triggers"]]
no_trigger = [n for n, d in skills.items() if not d["triggers"] and not d["disable-model-invocation"]]

ts = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
graph_data = {
    "ts": ts,
    "skills_count": len(skills),
    "edges_count": len(edges),
    "manual_only": manual_only,
    "auto_trigger": auto_trigger,
    "no_trigger": no_trigger,
    "skills": [
        {k: v for k, v in d.items() if k != "body"}
        for d in skills.values()
    ],
    "edges": [{"from": e[0], "to": e[1], "type": e[2]} for e in edges],
}

with open(OUTPUT_GRAPH, "a") as f:
    f.write(json.dumps(graph_data, ensure_ascii=False) + "\n")

print("Skills 총: " + str(len(skills)))
print("  자동 트리거 (UserPromptSubmit 매칭): " + str(len(auto_trigger)))
print("  사용자 명시 호출만 (disable-model-invocation): " + str(len(manual_only)))
print("  트리거 미정의: " + str(len(no_trigger)))
print()
print("의존 엣지 총: " + str(len(edges)))
path_count = sum(1 for e in edges if e[2] == 'path')
mention_count = sum(1 for e in edges if e[2] == 'mention')
print("  명시적 경로 참조 (path): " + str(path_count))
print("  단순 언급 (mention): " + str(mention_count))
print()
print("자동 트리거 skill:")
for n in sorted(auto_trigger):
    trig_count = len(skills[n]["triggers"])
    print("  - " + n + " (" + str(trig_count) + " 키워드)")
print()
print("사용자 명시 호출 skill:")
for n in sorted(manual_only):
    hint = skills[n].get("argument-hint", "")
    print("  - " + n + " " + hint)

# Mermaid + Markdown 생성
if not DRY_RUN:
    md_lines = []
    md_lines.append("# Skills Dependency Graph (자동 생성)")
    md_lines.append("")
    md_lines.append("> **갱신 시점**: " + ts)
    md_lines.append("> **생성 스크립트**: `.claude/scripts/generate-skill-graph.sh`")
    md_lines.append("> **raw 데이터**: `.claude/state/skill-graph.json`")
    md_lines.append("")
    md_lines.append("## 개요")
    md_lines.append("")
    md_lines.append("- Skills 총: **" + str(len(skills)) + "**")
    md_lines.append("  - 자동 트리거 (UserPromptSubmit 매칭): " + str(len(auto_trigger)))
    md_lines.append("  - 사용자 명시 호출만 (`disable-model-invocation: true`): " + str(len(manual_only)))
    md_lines.append("  - 트리거 미정의: " + str(len(no_trigger)))
    md_lines.append("- 의존 엣지 총: **" + str(len(edges)) + "** (path " + str(path_count) + ", mention " + str(mention_count) + ")")
    md_lines.append("")
    md_lines.append("## Mermaid 의존 그래프")
    md_lines.append("")
    md_lines.append("```mermaid")
    md_lines.append("graph TD")
    for n, d in sorted(skills.items()):
        label = n.replace("-", "_")
        md_lines.append("    " + label + "[\"" + n + "\"]:::skill")
    md_lines.append("    classDef skill fill:#bbf,stroke:#333")
    md_lines.append("    classDef manual fill:#9f9,stroke:#333")
    for n in manual_only:
        label = n.replace("-", "_")
        md_lines.append("    class " + label + " manual")
    for src, tgt, etype in edges:
        s = src.replace("-", "_")
        t = tgt.replace("-", "_")
        arrow = "-->" if etype == "path" else "-.->"
        md_lines.append("    " + s + " " + arrow + " " + t)
    md_lines.append("```")
    md_lines.append("")
    md_lines.append("범례:")
    md_lines.append("- **🟦 파란 노드**: 자동 트리거 (UserPromptSubmit 매칭)")
    md_lines.append("- **🟩 초록 노드**: 사용자 명시 호출만 (`disable-model-invocation`)")
    md_lines.append("- **→ 실선**: 명시적 경로 참조 (`skills/{name}/SKILL.md`)")
    md_lines.append("- **⇢ 점선**: 단순 이름 언급")
    md_lines.append("")
    md_lines.append("## Skills 인벤토리")
    md_lines.append("")
    md_lines.append("| Skill | 발동 | 트리거 수 | argument-hint | 출력 의존 |")
    md_lines.append("|---|---|---|---|---|")
    for n, d in sorted(skills.items()):
        invoke = "🟩 명시 호출" if d["disable-model-invocation"] else "🟦 자동 매칭"
        trig = len(d["triggers"])
        hint = d.get("argument-hint", "—")[:40] or "—"
        out_deps = sum(1 for e in edges if e[0] == n)
        md_lines.append("| " + n + " | " + invoke + " | " + str(trig) + " | " + hint + " | " + str(out_deps) + " |")

    md_lines.append("")
    md_lines.append("## 의존 매트릭스")
    md_lines.append("")
    sorted_names = sorted(skills.keys())
    md_lines.append("| FROM \\ TO | " + " | ".join(sorted_names) + " |")
    md_lines.append("|---|" + "|".join(["---"] * len(skills)) + "|")
    for src in sorted_names:
        row = [src]
        for tgt in sorted_names:
            if src == tgt:
                row.append("·")
            else:
                cell = ""
                for e in edges:
                    if e[0] == src and e[1] == tgt:
                        cell = "→" if e[2] == "path" else "⇢"
                        break
                row.append(cell)
        md_lines.append("| " + " | ".join(row) + " |")

    md_lines.append("")
    md_lines.append("## 분석 인사이트")
    md_lines.append("")
    md_lines.append("### 강한 의존 (path 참조 ≥2)")
    targets_count = {}
    for e in edges:
        if e[2] == "path":
            targets_count[e[1]] = targets_count.get(e[1], 0) + 1
    has_core = False
    for tgt, cnt in sorted(targets_count.items(), key=lambda x: -x[1]):
        if cnt >= 2:
            md_lines.append("- **" + tgt + "** ← " + str(cnt) + " skill에서 참조 (코어 skill 후보)")
            has_core = True
    if not has_core:
        md_lines.append("- 없음 (현재 모든 skill이 독립적이거나 1:1 참조)")

    md_lines.append("")
    md_lines.append("### 트리거 미정의 skill (명시 호출 + 자동 트리거 둘 다 안 됨)")
    if no_trigger:
        for n in no_trigger:
            md_lines.append("- ⚠️ **" + n + "** — 발동 경로 모호. triggers 추가 또는 disable-model-invocation 명시 권장")
    else:
        md_lines.append("- 없음 (모든 skill 발동 경로 명확)")

    md_lines.append("")
    md_lines.append("## 변경 이력")
    md_lines.append("")
    md_lines.append("| 일자 | 변경 |")
    md_lines.append("|---|---|")
    md_lines.append("| " + ts[:10] + " | 초기 생성 (Skills " + str(len(skills)) + " / Edges " + str(len(edges)) + ") |")
    md_lines.append("")
    md_lines.append("## 관련 정본")
    md_lines.append("")
    md_lines.append("- `.claude/scripts/generate-skill-graph.sh` — 본 문서 생성 스크립트")
    md_lines.append("- `.claude/skills/*/SKILL.md` — 각 skill 정본")
    md_lines.append("- `research/HARNESS_ENGINEERING.md` §14.2 — Skills 인벤토리")
    md_lines.append("- `AUTOMATION.md` §1.5 — Skills 매핑")
    md_lines.append("")

    with open(OUTPUT_MD, "w") as f:
        f.write("\n".join(md_lines))
    print()
    print("[기록] " + OUTPUT_MD)

print("[기록] " + OUTPUT_GRAPH)
print()
print("[RESULT] PASS — Skills graph 생성 완료")
PYEOF

echo "=== 끝 ==="
exit 0
