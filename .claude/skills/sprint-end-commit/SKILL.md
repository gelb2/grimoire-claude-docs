---
name: sprint-end-commit
description: Sprint 종료 commit + push develop 영역 — git status + add + commit + push 일괄. 메인 영역 매번 영역 영역 X = skill 영역 박제 영역.
allowed-tools: Bash
disable-model-invocation: true
trigger-mode: manual
effort: low
owner-agent: grimoire-harness
owner-skill: ""
responsibility-note: "Sprint 종료 commit + push 표준 절차 박제 — 사용자 명시 'commit + push' 후 영역 진입"
---

# Sprint End Commit — Sprint 종료 commit + push develop

## 책임 영역 (2026-05-10 Phase 2 박제)

- **owner**: grimoire-harness (`.claude/*` 메타 영역)
- **trigger 패턴**: `disable-model-invocation: true` — 사용자 명시 호출만
- **사용자 명시 키워드**: "Sprint 종료 commit" / "commit + push" / "push develop"

> **근거**: 본 세션 5/10 PAY-P3-B 종료 commit 사슬 (server `eb58a3d` + web `7e9673b` + claude-docs `b83fcd7`) 영역 정합 박제. 메인 영역 매번 명령 영역 영역 X = skill 영역 박제 영역.

## 사용자 결정 영역

- commit message 영역 사용자 결정 또는 메인 Claude 영역 자동 작성 (Sprint 종료 박제 영역 종속)
- main 머지 시점 = 별도 사용자 명시 (5/8 INFRA-1 사고 영역 회복 정합 = develop 자율 + main 사용자 명시)

## 표준 명령 묶음 (4 단계)

### 단계 1 — git status + diff 영역 박제

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire

# claude-docs (workspace 루트) 영역
git status

# 3 레포 영역 status (server / web / claude-docs)
git -C grimoire-server status
git -C grimoire-web status

# 변경 영역 매트릭스 박제
git -C grimoire-server diff --stat
git -C grimoire-web diff --stat
git diff --stat
```

### 단계 2 — git add 영역 (specific files only, NOT `add -A` / `add .`)

```bash
# 영역별 specific add 영역 강제 (sensitive file / 큰 binary 영역 회피)
git -C grimoire-server add <file1> <file2> ...
git -C grimoire-web add <file1> <file2> ...
git add <file1> <file2> ...

# .env / credentials.json 영역 commit 영역 절대 금지 박제
```

### 단계 3 — commit 영역 (HEREDOC 형식 강제)

```bash
# Sprint 종료 영역 commit message HEREDOC 형식 강제 (개행 박제 정합)
git -C grimoire-server commit -m "$(cat <<'EOF'
feat(sprint): SPRINT-NAME 영역 종료 — 핵심 박제 (sprint #N_M)

- 변경 1
- 변경 2
- 변경 3

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

git -C grimoire-web commit -m "$(cat <<'EOF'
feat(sprint): ...
EOF
)"

git commit -m "$(cat <<'EOF'
feat(harness): ...
EOF
)"
```

**commit message 영역 한국어 정합 강제** (CLAUDE.md §2 영역).

### 단계 4 — push develop 영역

```bash
# develop 브랜치 영역 강제 (main 영역 사용자 명시 후만)
git -C grimoire-server push origin develop
git -C grimoire-web push origin develop
git push origin develop

# 사후 git log 영역 박제
git -C grimoire-server log --oneline -5
git -C grimoire-web log --oneline -5
git log --oneline -5
```

## destructive 영역 절대 금지

- `git push --force` — 사용자 명시 후만
- `git reset --hard` — 사용자 명시 후만
- `git checkout .` — 사용자 명시 후만
- `git clean -f` — 사용자 명시 후만
- `--no-verify` (hook 영역 skip) — 사용자 명시 후만
- `--amend` — 절대 금지 (NEW commit 영역 강제)

## main 머지 영역 (사용자 명시 후만)

```bash
# 3 레포 영역 develop → main per-repo 명시 영역 진입
git -C grimoire-server checkout main
git -C grimoire-server merge develop --no-ff
git -C grimoire-server push origin main
git -C grimoire-server checkout develop

# 동일 영역 web / claude-docs 영역 진입
```

**근거**: 5/8 INFRA-1 사고 영역 (server main merge 자동 배포 트리거 위반) 영역 회복 정합.

## 박제 의무 (Mitchell Ghostty 정합)

명령 묶음 영역 진행 중 발견하는 결함 / 우회 / 거짓 보고 영역 즉시 박제:

```bash
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/incident-log.sh \
  sprint_end_commit {severity} {source} "{description}"
```

## 관련 정본
- `CLAUDE.md` §2 — 한국어 commit message 강제
- `.githooks/AGENTS.md` — Git/Pre-Push 정책
- `HANDOVER_NEXT_SESSION.md` — Sprint 종료 박제 영역 정본
- `memory/project_session_20260510.md` — 본 세션 commit 사슬 영역 정합

## 변경 이력
- 2026-05-10 #10_8 Phase 2: 신설 — 사용자 명시 (5/10) "다 진행해" + Phase 2 8건 skill 영역 3번째. 본 세션 PAY-P3-B 종료 commit 사슬 (server `eb58a3d` + web `7e9673b` + claude-docs `b83fcd7`) 영역 정합 박제. 메인 영역 매번 git 명령 영역 영역 X = skill 영역 박제 영역 영역.
