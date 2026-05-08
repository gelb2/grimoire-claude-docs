---
name: drift-check
description: HARNESS_ENGINEERING.md §14 인벤토리 vs 실측(Skills/Sensors/Hooks/Knowledge/Agents 카운트) drift 자동 검증. 사용자 명시 호출만 (`/drift-check`). InstructionsLoaded hook으로 매 세션 자동 실행되지만, 작업 중 즉시 확인 시 사용.
disable-model-invocation: true
allowed-tools: Bash, Read
effort: low
paths:
  - ".claude/skills/**"
  - ".claude/scripts/sensor-*.sh"
  - ".claude/agents/grimoire-*.md"
  - ".claude/knowledge/*.md"
  - "research/HARNESS_ENGINEERING.md"
---

> **2026-05-06 묶음 PP-3 ARCHIVE**: 30일간 자율 호출 0회 + disable-model-invocation: true + 비상 가치 낮음. 비상 시 `.claude/skills/_archive/drift-check/SKILL.md` 직접 Read 또는 사용자 명시 호출.

# Drift Check — 인벤토리 정합 검증

## 사용 패턴

```bash
bash .claude/scripts/instructions-drift-check.sh
```

## 결과 해석

- exit 0: 모든 카운트 정합 (Skills/Sensors/Hooks/Knowledge/Agents)
- exit 1+: 1건 이상 drift — 즉시 갱신 필요
  - HARNESS_ENGINEERING.md §14.{N} 카운트 갱신
  - 또는 실측 자체를 정합화

## 트리거

- 새 skill/sensor/hook/knowledge/agent 추가 후
- HARNESS §14 갱신 후
- 회귀에서 06-drift-zero.json FAIL 시

상세: `eval/tasks/06-drift-zero.json`, `.claude/scripts/instructions-drift-check.sh`
