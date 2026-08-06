---
name: memory-status
description: memory/MEMORY.md 인덱스 + project_remaining_tasks.md + 최근 세션 기록 표출. 사용자 명시 호출만 (`/memory-status`). 세션 시작 또는 중간 점검 시.
disable-model-invocation: true
allowed-tools: Bash, Read
effort: low
trigger-mode: keyword (triggers field) — paths 미적용 명시 (NEW-16 J4 패턴)
triggers:
  - "memory-status"
  - "메모리 봐"
  - "기억 정리"
  - "메모리 점검"
  - "memory 상태"
---

# Memory Status — 메모리 현황 점검

> **trigger-mode**: user-invocation (disable-model-invocation:true). paths 미적용 — 사용자 `/memory-status` 명시 호출만.

## 사용 패턴

```bash
# MEMORY.md 인덱스
cat /Users/sokol/.claude/projects/-Users-sokol-Git-ProjectGrimoire/memory/MEMORY.md

# 남은 과제
cat /Users/sokol/.claude/projects/-Users-sokol-Git-ProjectGrimoire/memory/project_remaining_tasks.md

# 최근 세션 기록 (5건)
ls -lt /Users/sokol/.claude/projects/-Users-sokol-Git-ProjectGrimoire/memory/project_session_*.md | head -5
```

## 트리거

- 세션 시작 시 (다음에 뭐 할지 점검)
- 사용자 "어디까지 했지?" 질문 시
- 메모리 갱신 필요 점검 시

## 절대 규칙 참조

- 메모리 디렉토리는 `/Users/sokol/.claude/projects/-Users-sokol-Git-ProjectGrimoire/memory/` (사용자 홈)
- 세션 종료 전 `project_session_YYYYMMDD[_N].md` 작성 + MEMORY.md 인덱스 갱신 필수

상세: `.claude/AGENTS.md` §1 (메모리 절대 규칙)
