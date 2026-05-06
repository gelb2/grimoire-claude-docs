---
name: eval-run
description: ProjectGrimoire eval 시스템(eval/scripts/eval-runner.sh) 실행 단축 슬래시. 사용자 명시 호출만 (`/eval-run [regression|edd]`). regression(기본)은 결정적 검증, edd는 확률적 평가(runs=10).
argument-hint: "[선택: regression | edd] (기본 regression)"
disable-model-invocation: true
allowed-tools: Bash, Read
effort: low
paths:
  - "eval/tasks/**/*.json"
  - "eval/tasks-edd/**/*.json"
  - "eval/scripts/*.sh"
  - "eval/scripts/*.py"
---

> **2026-05-06 묶음 PP-3 ARCHIVE**: 30일간 자율 호출 0회 + disable-model-invocation: true + 비상 가치 낮음. 비상 시 `.claude/skills/_archive/eval-run/SKILL.md` 직접 Read 또는 사용자 명시 호출.

# Eval Run — 회귀 + EDD 단축 호출

## 사용 패턴

```bash
# regression (기본) — 결정적 검증
bash eval/scripts/eval-runner.sh

# EDD — 확률적 평가 (runs=10)
bash eval/scripts/eval-runner.sh --mode=edd

# EDD 단축 (runs=2)
bash eval/scripts/eval-runner.sh --mode=edd --runs=2
```

## 결과 해석

- regression: PASS/TOTAL 100% 필수 (1.0 임계)
- EDD: 카테고리별 임계 (security 0.95+, edge_case 0.75 등) — 책 Ch 15

## 검증 후

- 100% PASS → 안전 커밋 가능
- 1건 이상 FAIL → 분석 + 수정 → 재실행
- baseline.csv / edd-baseline.csv 자동 적재

상세: `eval/README.md`, `research/HARNESS_SPLIT_AND_EDD.md` §17 (책 Ch 15 EDD 박제, 2026-05-02 묶음 L M3 분리)
