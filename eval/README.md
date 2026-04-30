# ProjectGrimoire Eval 시스템 (EDD)

> Eval-Driven Development — TDD의 AI 시대 버전.
> 책 정본: "하네스 엔지니어링 완전 정복" (shuntailor 2026-03) Ch 15.
> 도입: 2026-04-27 #9 (P0 갭 해소 — Verify 기둥 2.5/5 → 4/5 목표).

## 동기

ProjectGrimoire 8 세션 누적의 운영 회귀 (AI 분석 fetch aborted / 테마 플리커 / §0 분석/베스트 / SDK signal 누락 / 결제 원자성 / 보안 시크릿 / docs-sync drift 등)를 **반복 가능한 자동 검증**으로 박제. 책의 핵심 인용:

> "완벽한 Eval보다 돌아가는 Eval이 낫다. 20개 태스크, 코드 기반 채점으로 시작하라."
> — Anthropic, 'Demystifying Evals for AI Agents'

## 두 가지 모드

| Mode | 본질 | runs | threshold | 용도 |
|---|---|---|---|---|
| **회귀 Eval** (현재 도입) | 현재 코드베이스 상태 검증 | 1 (결정적) | 1.0 (모두 통과 필수) | 운영 회귀 차단 — Stripe 1,000 PR/주 모델 |
| **EDD Eval** (향후) | 에이전트 새 작업 결과 평가 | 10 (확률적) | 0.7~0.95 카테고리별 | 에이전트 정확도 측정 + 하네스 진화 입력 |

본 디렉토리는 **회귀 Eval 우선** (book Ch 15 "20개 태스크로 시작" 권장 적용).

## 디렉토리 구조

```
eval/
├── README.md            ← 본 파일
├── tasks/               ← 20개 실패 박제 (.json)
│   ├── 01-analysis-cancel-refund.json
│   ├── 02-theme-flicker.json
│   ├── ... (8 세션 누적 회귀 사례)
│   └── 20-prisma-migration-consistency.json
├── scripts/
│   ├── eval-runner.sh   ← 메인 실행기
│   ├── grade.py         ← 코드 기반 채점
│   └── grade-llm.py     ← (향후) LLM-as-Judge
└── results/             ← 기준선 + 실행 결과 (.gitignore)
    ├── baseline.csv
    └── YYYY-MM-DD-HH-MM-SS/
```

## 평가 카테고리 (책 Ch 15 권장 + ProjectGrimoire 도메인 추가)

| 카테고리 | 임계값 | 가중치 | ProjectGrimoire 매핑 |
|---|---|---|---|
| 타입 안전성 | 9/10 | 높음 | tsc --noEmit 통과 |
| API 규격 | 8/10 | 높음 | docs/api-contract.md 정합 |
| 엣지 케이스 | 7/10 | 중간 | abortableRace + 환불 분기 |
| 코딩 컨벤션 | 8/10 | 중간 | ESLint + 헥사고날 / FSD |
| 테스트 커버리지 | 6/10 | 낮음 | server 60% / web 55% |
| **§0 원가** ★ | 9/10 | 높음 | 안전배수 ≥3.0× (PLANNING §0) |
| **사슴악마 시각 정본** ★ | 10/10 | 높음 | CLAUDE.md §1 정본 준수 |
| **작가 콘텐츠 보호** ★ | 10/10 | 높음 | 본문 수정/인용/로깅 0건 |
| **보안** ★ | 10/10 | 높음 | 시크릿 평문 0건, mutation guard, BFF 프록시 |

## Task 형식 (책 정합 + ProjectGrimoire 확장)

```json
{
  "id": "regression-001",
  "name": "AI 분석 cancel 시 자동 환불",
  "category": "edge_case",
  "source_session": "20260419_4",
  "prompt": "사용자가 AI 분석 진행 중 cancel 클릭 시 크레딧이 자동 환불되는가?",
  "eval_criteria": [
    {"type": "code", "check": "abortable_race_used", "desc": "novel-analysis.usecase.ts에 abortableRace 호출 존재"},
    {"type": "code", "check": "refund_in_catch", "desc": "catch 블록에서 adjustCredits +N 호출"},
    {"type": "code", "check": "sdk_signal_passed", "desc": "askClaude options.signal 전달"},
    {"type": "test", "check": "abort_test_pass", "desc": "novel-analysis.usecase.spec.ts AbortSignal 테스트 통과"}
  ],
  "threshold": 1.0,
  "runs": 1
}
```

## 실행

```bash
# 전체 20 태스크 실행
bash eval/scripts/eval-runner.sh

# 단일 태스크 실행
bash eval/scripts/eval-runner.sh tasks/01-analysis-cancel-refund.json

# CI/CD에서 (regression-tolerance 0.05)
# .github/workflows/eval.yml
```

## 기준선 (Baseline)

`results/baseline.csv`에 매 실행 누적. 통과율 추이로 하네스 진화 추적.

## CI/CD 통합 (Stripe 모델)

`.github/workflows/eval.yml` (server/web/claude-docs 각 레포):
- `paths` 트리거: harness 영향 영역만 (`.claude/**`, `eval/**`, `CLAUDE.md`)
- regression-tolerance 0.05 (5%p 이상 하락 시 PR fail)
- PR 코멘트 자동 게시

## 책 vs ProjectGrimoire 적용 차이

| 책 표준 | ProjectGrimoire 적용 |
|---|---|
| 에이전트 실행 후 채점 (EDD) | **현재 코드 상태 검증** (회귀 eval) — 운영 안정 우선 |
| runs=10 + threshold=0.8 | runs=1 + threshold=1.0 (결정적) |
| LLM-as-Judge 권장 | 코드 기반 우선 (LLM은 P1 후속) |
| 단일 레포 | 멀티 레포 (claude-docs / server / web) — 각 레포에 eval/ |

## 관련 정본

- `research/HARNESS_ENGINEERING.md` Ch 15 EDD
- `CLAUDE.md` §0 ZERO-TOLERANCE (작가 본문 / §0 원가 / 시각 정본)
- `.claude/scripts/sensor-*.sh` (eval과 보완 — sensor는 단일 항목, eval은 종합 패키지)
- `.claude/skills/verification-before-completion/SKILL.md` (Gate 1·2·3 — eval과 결합)

---

마지막 업데이트: 2026-04-27 (P0 도입)
승격 원본: "하네스 엔지니어링 완전 정복" (shuntailor 2026-03) Ch 15
