---
name: sprint-handover-finalize
description: Sprint 종료 박제 영역 — HANDOVER 갱신 + memory/project_session_*.md 갱신 + claude-docs commit + push 일괄. 메인 영역 매번 영역 영역 X = skill 영역 박제.
allowed-tools: Bash, Edit, Write
disable-model-invocation: true
trigger-mode: manual
effort: medium
owner-agent: grimoire-harness
owner-skill: ""
responsibility-note: "Sprint 종료 박제 표준 절차 — HANDOVER + memory + claude-docs commit 일괄 절차 박제"
---

# Sprint Handover Finalize — Sprint 종료 박제 표준 영역

## 책임 영역 (2026-05-10 Phase 2 박제)

- **owner**: grimoire-harness (`.claude/*` 메타 + memory + HANDOVER + claude-docs 영역)
- **trigger 패턴**: `disable-model-invocation: true` — 사용자 명시 호출만
- **사용자 명시 키워드**: "Sprint 종료" / "handover finalize" / "세션 종료 박제" / "사용자 직접 영역 인계"

> **근거**: 본 세션 5/10 PAY-P3-B 종료 + PAY-P3-E §7-1 단계 1~6 종료 박제 영역 (HANDOVER §1.7 + §1.8 + memory project_session_20260510.md + claude-docs commit `b83fcd7`/`adf6471`/`a3d9939`) 영역 정합.

## 사용자 결정 영역

- HANDOVER 갱신 영역 자율 진입 / 사용자 명시 종속
- memory 영역 갱신 영역 자율 진입 (사용자 절대 규칙 = 세션 종료 시 메모리 기록 강제)
- main 머지 영역 = 별도 사용자 명시

## 표준 명령 묶음 (5 단계)

### 단계 1 — Sprint 종료 박제 영역 데이터 수집

```bash
# 본 세션 commit 사슬 영역 박제
git -C grimoire-server log --oneline -10
git -C grimoire-web log --oneline -10
git log --oneline -10

# 본 세션 인벤토리 변동 영역 박제 (jest / eval / sensor / shared-contracts 등)
ls /Users/sokol/Git/ProjectGrimoire/.claude/scripts/sensor-*.sh | wc -l
ls /Users/sokol/Git/ProjectGrimoire/eval/tasks/*/*.json | wc -l
grep -c "^## §" /Users/sokol/Git/ProjectGrimoire/.claude/shared-contracts.md
```

### 단계 2 — HANDOVER_NEXT_SESSION.md 영역 갱신

```bash
# §1.X 신설 영역 (본 세션 박제 영역 첫 영역)
# Edit tool 영역 — 메인 Claude 직접 또는 grimoire-harness 영역 진입
```

**HANDOVER §1.X 영역 정본 영역 영역**:
- 본 세션 commit 사슬 영역 박제 (commit sha + 변경 영역)
- 본 세션 인벤토리 변동 영역 박제 (jest / eval / sensor 등)
- 다음 세션 1순위 영역 (옵션 A / B 영역)
- 사용자 결정 영역 박제
- 사용자 안전 영역 박제 (Mitchell Ghostty 정합 영역, 사용자 발화 영역 정직 영역)

### 단계 3 — memory/project_session_YYYYMMDD_N.md 영역 갱신

```bash
# 새 세션 영역 박제 또는 기존 영역 영역 갱신 영역
# Edit / Write tool 영역
```

**memory 영역 정본 영역 영역**:
- 세션 그룹 영역 (예: ### 5월 9~10 (#10_8 PAY-P3-X 영역 종료))
- commit sha + 변경 영역
- 본 세션 영역 박제 결정 사항 영역
- 다음 세션 1순위 영역

### 단계 4 — incident-log 영역 박제

```bash
# 본 세션 박제 영역 incident-log 영역 누적 박제 영역 박제
wc -l /Users/sokol/Git/ProjectGrimoire/.claude/state/incident-log.jsonl

# 본 세션 신설 영역 박제 횟수 영역 (필요 영역 grep으로 박제 영역)
grep "$(date -u +%Y-%m-%d)" /Users/sokol/Git/ProjectGrimoire/.claude/state/incident-log.jsonl | wc -l
```

### 단계 5 — claude-docs commit + push develop 영역

```bash
cd /Users/sokol/Git/ProjectGrimoire

# specific add 영역 강제 (sensitive file 영역 회피)
git add HANDOVER_NEXT_SESSION.md
git add memory/project_session_*.md
git add .claude/state/*.jsonl
git add .claude/state/*.md
# 영역 etc

# Sprint 종료 영역 commit (HEREDOC 형식 영역 정합)
git commit -m "$(cat <<'EOF'
docs(handover): §1.X 신설 — SPRINT-NAME 영역 종료 박제 (sprint #N_M)

- 본 세션 commit 사슬: server <sha> + web <sha> + claude-docs <sha>
- 본 세션 인벤토리 변동: jest +N / eval +N / sensor +N
- 다음 세션 1순위: 옵션 A / B
- 사용자 결정 영역 박제

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

# develop 브랜치 영역 강제
git push origin develop

# 사후 git log 영역 박제
git log --oneline -3
```

## destructive 영역 절대 금지

`sprint-end-commit` skill 영역 정합 — `--force` / `reset --hard` / `checkout .` / `clean -f` / `--no-verify` / `--amend` 영역 절대 금지.

## 박제 의무 (Mitchell Ghostty 정합)

박제 영역 진행 중 발견하는 결함 / 우회 / 거짓 보고 영역 즉시 박제:

```bash
bash /Users/sokol/Git/ProjectGrimoire/.claude/scripts/incident-log.sh \
  sprint_handover_finalize {severity} {source} "{description}"
```

## 관련 정본
- `HANDOVER_NEXT_SESSION.md` — Sprint 종료 박제 정본
- `memory/project_session_*.md` — 세션별 박제
- `.claude/state/incident-log.jsonl` — incident 영역 누적 박제
- `.claude/skills/sprint-end-commit/SKILL.md` — commit + push 영역 (본 skill 단계 5 영역 정합)
- `.claude/skills/handover-refresh/SKILL.md` — 영역 영역 (5/10 _archive 영역, GRAY)
- `.claude/agents/grimoire-harness.md` — 책임 agent 자기 정의

## 변경 이력
- 2026-05-10 #10_8 Phase 2: 신설 — 사용자 명시 (5/10) "다 진행해" + Phase 2 8건 skill 영역 8번째 (마지막). 본 세션 5/10 PAY-P3-B + PAY-P3-E §7-1 단계 1~6 종료 박제 영역 (HANDOVER §1.7 + §1.8 + memory + claude-docs commit `b83fcd7`/`adf6471`/`a3d9939`) 영역 정합 박제. 메인 영역 매번 5 단계 명령 영역 영역 X = skill 영역 박제 영역.
