---
name: eval-run
description: ProjectGrimoire eval 시스템(eval/scripts/eval-runner.sh + eval-precommit.sh) 실행 영역 — 사용자 명시 호출 영역. regression(기본)은 결정적 검증, edd는 확률적 평가(runs=10).
argument-hint: "[선택: regression | edd] (기본 regression)"
disable-model-invocation: true
allowed-tools: Bash, Read
trigger-mode: manual
effort: low
owner-agent: grimoire-qa
owner-skill: ""
responsibility-note: "eval regression + EDD 영역 표준 실행 절차 박제 — 5/10 Phase 2 박제 영역 _archive 영역에서 정상 영역 활성화 정합"
paths:
  - "eval/tasks/**/*.json"
  - "eval/tasks-edd/**/*.json"
  - "eval/scripts/*.sh"
  - "eval/scripts/*.py"
---

# Eval Run — 회귀 + EDD 영역 표준 실행

## 책임 영역 (2026-05-10 Phase 2 박제)

- **owner**: grimoire-qa (eval/tasks/* + eval/scripts/* 영역)
- **trigger 패턴**: `disable-model-invocation: true` — 사용자 명시 호출만
- **사용자 명시 키워드**: "eval 실행" / "regression 검증" / "EDD 평가" / "회귀 검증"

> **근거**: 2026-05-06 묶음 PP-3 영역 ARCHIVE 정합 박제 → 2026-05-10 Phase 2 영역 정상 영역 활성화 (사용자 명시 "Phase 2 진행" 정합 영역).

## 사용 패턴

### regression (기본) — 결정적 검증

```bash
bash /Users/sokol/Git/ProjectGrimoire/eval/scripts/eval-runner.sh
```

**임계 영역**: PASS/TOTAL 100% 필수 (1.0 임계 영역). 1건 이상 FAIL 영역 발견 시 즉시 STOP.

### EDD — 확률적 평가 (runs=10 기본)

```bash
bash /Users/sokol/Git/ProjectGrimoire/eval/scripts/eval-runner.sh --mode=edd
```

### EDD 단축 (runs=2)

```bash
bash /Users/sokol/Git/ProjectGrimoire/eval/scripts/eval-runner.sh --mode=edd --runs=2
```

### Pre-commit eval 영역 (commit 전 검증 영역)

```bash
bash /Users/sokol/Git/ProjectGrimoire/eval/scripts/eval-precommit.sh
```

## 결과 해석

### regression 영역
- PASS/TOTAL 100% 필수 (1.0 임계)
- baseline.csv 영역 자동 적재
- 5/10 종료 영역: 69/69 PASS 박제

### EDD 영역
- 카테고리별 임계 (security 0.95+, edge_case 0.75 등)
- edd-baseline.csv 영역 자동 적재
- 책 Ch 15 영역 정본

## 검증 후 영역

- 100% PASS → 안전 commit 영역 가능
- 1건 이상 FAIL → 분석 + 수정 → 재실행 영역 강제
- 결과 영역 박제 → reports/QA_REPORT.md (qa 위임 영역) 또는 메모리

## 사후 박제 영역

```bash
# 결과 영역 박제 (Sprint 종료 영역 또는 사용자 보고 영역)
echo "=== eval-run 결과 ==="
echo "mode: regression / edd"
echo "PASS/TOTAL: N/N (100% / X%)"
echo "baseline.csv 영역 갱신: <commit-sha>"
```

## 박제 의무 (Mitchell Ghostty 정합)

eval 영역 진행 중 발견하는 결함 / 우회 / 거짓 보고 영역 즉시 박제:

```bash
bash /Users/sokol/Git/ProjectGrimoire/.claude/scripts/incident-log.sh \
  eval_run {severity} {source} "{description}"
```

## 관련 정본
- `eval/scripts/eval-runner.sh` — 표준 실행 영역
- `eval/scripts/eval-precommit.sh` — pre-commit 영역 실행
- `eval/scripts/grade-llm.py` — LLM-as-Judge (cost guard ₩2K/일 ₩50K/월)
- `eval/scripts/grade.py` — 결정적 채점
- `eval/README.md` — eval 시스템 정본
- `research/HARNESS_SPLIT_AND_EDD.md` §17 — 책 Ch 15 EDD 정본
- `.claude/agents/grimoire-qa.md` — 책임 agent 자기 정의

## 변경 이력
- 2026-05-10 #10_8 Phase 2: 정상 영역 활성화 — 사용자 명시 (5/10) "다 진행해" + Phase 2 8건 skill 영역 5번째. `_archive/eval-run/SKILL.md` 영역 (2026-05-06 묶음 PP-3 GRAY 영역 박제) → 정상 영역. 사용자 명시 호출 영역 표준 절차 영역 박제 정합.
- 2026-05-06 #10_8 묶음 PP-3: ARCHIVE — 30일간 자율 호출 0회 + disable-model-invocation: true + 비상 가치 낮음.
