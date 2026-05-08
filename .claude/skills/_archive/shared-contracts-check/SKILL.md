---
name: shared-contracts-check
description: .claude/shared-contracts.md ↔ 7 에이전트 .md / reports / 코드 인터페이스 정합 자동 검증. 사용자 명시 호출만 (`/shared-contracts-check`). 책 Ch 16 shared contracts 패턴 준수 강제.
disable-model-invocation: true
allowed-tools: Bash, Read
effort: low
paths:
  - ".claude/shared-contracts.md"
  - ".claude/agents/grimoire-*.md"
  - "reports/*.md"
  - "grimoire-server/src/lib/claude.ts"
  - "grimoire-server/src/domain/model/config.ts"
---

> **2026-05-06 묶음 PP-3 ARCHIVE**: 30일간 자율 호출 0회 + disable-model-invocation: true + 비상 가치 낮음. 비상 시 `.claude/skills/_archive/shared-contracts-check/SKILL.md` 직접 Read 또는 사용자 명시 호출.

# Shared Contracts Check — 책 Ch 16 정합 검증

## 사용 패턴

```bash
bash .claude/scripts/sensor-shared-contracts.sh
```

## 검증 항목 (10 인터페이스)

1. PLANNER_REPORT (planner → server/web)
2. COST_AUDIT_REPORT
3. VISUAL_CANON_REPORT
4. DEV_REPORT
5. QA_REPORT
6. AskOptions (signal: AbortSignal)
7. ANALYSIS_CREDIT_COST = 4
8. Eval task 형식
9. LLM-as-Judge 가드 (₩2K/일 ₩50K/월)
10. PostToolUseFailure hook

## 트리거

- shared-contracts.md 수정 후
- 7 에이전트 .md 수정 후
- 새 인터페이스 도입 시

상세: `.claude/knowledge/book-harness-engineering-completion.md` Ch 16
