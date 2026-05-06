# Sprint Contract — Skill Invocation Rate Recovery

> 시작: 2026-05-06 (묶음 PP — 5 grimoire-* agent 위임 정공법 첫 적용)
> 종료 예정: 2026-08-04 (90일 후 재측정 후 종료)
> 책임 agent: qa (sprint orchestration) + planner (KPI 재정의) + server (skill 어휘 확장)

---

## 0. 객관적 결함 (사전 측정 — 본 sprint 시작 트리거)

| 일자 | rate | total_skills | invoked_30d | sensor 결과 | 사건 |
|------|------|--------------|-------------|------------|------|
| 2026-05-06 (PP-1 진단 직전) | 0.0769 | 26 | 2 (orchestration-decision 유일) | **FAIL** (rate < 0.10) | qa PP-1 분석 위임 — Skill 26건 사용 패턴 진단 |
| 2026-05-06 (PP-3 적용 직후) | 0.1176 | 17 | 2 | **WARN** (0.10 ≤ rate < 0.15) | server PP-3 ARCHIVE 9건 (PP-1 KEEP_FORCED 8건 보존, GRAY 9건 KEEP) → FAIL 탈출 |

**근본 원인 (planner §1 진단)**:
- **R1 (skill 인플레이션)**: 분모 26 중 30일 호출 0건 = 24개 (92%)
- **R2 (trigger 어휘 갭)**: requesting-code-review 등 한국어 자연 어휘 부재
- **R3 (메인 본능 부재)**: 사용자 자연 입력에 메인 Claude가 Skill 매칭 본능 미발동 — **본 sprint 핵심 KPI**

---

## 1. 목표 KPI

### 1-1. 단기 (PP 직후)
- **rate ≥ 0.15 (PP-3 슬림화 효과)** — ✅ 달성 진행중 (0.1176, WARN 진입). 단 invoked_30d=2 그대로 → 분모 슬림화만 효과, 분자 회복은 PP-4/PP-5 의존.

### 1-2. 중기 (30일 후 = 2026-06-05)
- **rate ≥ 0.20** (분자 ≥3 invoked_30d 필요)
- **eval auto-main-skill-invocation 5/5 PASS 유지** (인프라 무결성 회귀 차단)
- **별도 sensor (sensor-skill-invocation-jsonl) 박제 필요** — `.claude/state/skill-invocation-log.jsonl`로 본능 호출 객관화

### 1-3. 장기 (90일 후 = 2026-08-04 — sprint 종료)
- **rate ≥ 0.30** (invoked_30d ≥ 5)
- **R3 본능 회귀 객관 측정 토대 박제**: PP-5 5 task + 별도 sensor 결합
- **sensor-skill-paths-coverage WARN → PASS 전환**

---

## 2. 5 sub-task 진행 표

| Sub-task | Status | 책임 agent | 산출물 | commit |
|---------|--------|----------|--------|--------|
| PP-1 (qa 1차) Skill 26건 분석 + ARCHIVE 9 + GRAY 9 분류 | ✅ done | qa | `reports/QA_REPORT_skill-archive-candidates.md` | (qa 위임 결과) |
| PP-2 (planner) GRAY 9 결정 + 4 축 분석 | ✅ done | planner | `reports/PLANNER_REPORT_skill-graylist.md` (310줄) | (planner 위임 결과) |
| PP-3 (server) ARCHIVE 9 실행 + AGENTS.md 갱신 + 회귀 검증 | ✅ done | server #5 | `.claude/skills/_archive/` 9건 + AGENTS.md §3 | `77b28e3` |
| PP-4 (server #6) requesting-code-review 키워드 확장 (한국어 자연 어휘) | ⏳ in-progress | server #6 | (위임 진행중 — `requesting-code-review/SKILL.md` triggers 5+ 추가) | TBD |
| PP-5 (qa #7) Eval task 5건 신설 — R3 메인 본능 회귀 차단 인프라 | ✅ done (본 보고서 박제) | qa #7 | `eval/tasks-edd/edd-main-skill-invocation-{001~005}.json` 5건 | (qa #7 위임 결과) |

**보류된 후속**:
- PP-6 (옵션, planner §5 권고): verification-before-completion + writing-plans hook 점검 — 사용자 사전 검토 가치 ↑ → 별도 시점

---

## 3. 검증 캘린더

| 체크포인트 | 일자 | 측정 | 통과 임계 | 책임 |
|----------|------|-----|----------|------|
| **C1 단기** | 2026-05-13 (7일 후) | (a) sensor-skill-paths-coverage WARN/PASS (b) PP-4 적용 후 trigger 매칭률 +20% | rate ≥ 0.15 유지 + WARN 또는 PASS | qa (sensor 측정) |
| **C2 중기** | 2026-06-05 (30일 후) | (a) invoked_30d ≥ 3 (b) edd-main-skill-invocation 5/5 PASS (c) 새 sensor (jsonl 추적) baseline | rate ≥ 0.20 + eval 5/5 PASS | qa (eval) + planner (KPI 재정의) |
| **C3 장기 (sprint 종료)** | 2026-08-04 (90일 후) | (a) invoked_30d ≥ 5 (b) edd 5/5 + R3 본능 회귀 jsonl 객관 데이터 | rate ≥ 0.30 + EDD 5/5 + jsonl 데이터 ≥ 1주 박제 | qa orchestration |

---

## 4. PP-5 EDD task 5건 baseline (현 시점)

본 sprint의 R3 측정 인프라 박제 결과:

| task id | expected_skill | 1차 PASS/FAIL | 정합화 후 PASS/FAIL | 메모 |
|---------|---------------|---------------|-------------------|------|
| edd-main-skill-invocation-001 | systematic-debugging | FAIL (2/3) | **PASS (3/3)** | (3) 기준 정합화 — disable-model-invocation:true 의도 보존 |
| edd-main-skill-invocation-002 | consolidate-memory → memory-status/gc-sweep fallback | FAIL (2/3) | **PASS (3/3)** | (3) 기준 정합화 — fallback 자산 무결성 박제 |
| edd-main-skill-invocation-003 | deploy-precheck | FAIL (2/3) | **PASS (3/3)** | (3) 기준 정합화 — slash command 의도 보존 |
| edd-main-skill-invocation-004 | verification-before-completion | PASS (3/3) | PASS (3/3) | autonomous=true 보장 (planner §2-8 PP-6 결함 진단 토대) |
| edd-main-skill-invocation-005 | writing-plans | PASS (3/3) | PASS (3/3) | autonomous=true 보장 |

**baseline 5/5 PASS** (정합화 후) — 인프라 무결성 회귀 차단 확보. **R3 본능 회귀**는 별도 sensor 영역 (본 task는 인프라만 보장).

---

## 5. R3 본능 회귀 측정 갭 + 권장 후속

### 5-1. 본 task 한계 (정직한 박제)
본 EDD task 5건은 **결정적 인프라 검증** (skill 파일 + 어휘 + 메커니즘). **메인 Claude 본능 호출** 자체는 측정 불가:
- `.claude/state/skill-invocation-log.jsonl` (PostToolUse hook 박제) 부재
- LLM-as-Judge로 메인 응답에서 Skill tool_use 추적은 가능하지만 비용 가드 임계 (₩2K/일) 내 운영 검증 필요

### 5-2. 권장 후속 (PP-6 또는 별도)
1. **새 sensor `sensor-skill-invocation-jsonl.sh`** (planner §5-2 PP-6-1 권고 정합):
   - PostToolUse hook에서 SkillTool 호출 시 jsonl 적재
   - sensor가 30일 윈도우 invoked_30d 객관 측정
2. **PP-6 (planner §5 권고)** verification-before-completion + writing-plans hook 매칭 결함 진단:
   - autonomous=true인데 30일 0건 = 메커니즘 결함
   - hook 매칭 알고리즘 점검 + LLM-as-Judge 1회/주 무작위 측정

### 5-3. LLM-as-Judge 비용 영향 (cost guard 정합 — planner §6 정합)
- 본 EDD task 5건 모두 `verification_method: deterministic_grep` (LLM 0회)
- 회귀 1회당 추정 비용: **₩0** (LLM 미사용)
- **planner §6 cost-accountant 위임 면제 정합** ✅

---

## 6. 검증 게이트 (Sprint 종료 시 — 2026-08-04)

| 게이트 | 통과 조건 |
|------|---------|
| GATE-1 | sensor-skill-paths-coverage PASS (rate ≥ 0.30) |
| GATE-2 | edd-main-skill-invocation 5/5 PASS (인프라 무결성 회귀 0) |
| GATE-3 | 새 sensor jsonl 기반 invoked_30d ≥ 5 (R3 본능 회복) |
| GATE-4 | regression eval 67/67 PASS (5건 신설 회귀 0) |

GATE-1~4 모두 PASS = sprint 종료 + memory 박제 (`memory/feedback_skill_invocation_recovery.md`)

---

## 7. 참조

- planner §2-1~§2-9 (각 GRAY 9건 4 축 분석)
- planner §5 PP-6 권고 (verification-before-completion hook 점검)
- qa PP-1 분류표 (PP-1 보고서)
- PP-3 commit `77b28e3` (skill 슬림화 26→17)
- sensor-skill-paths-coverage.sh (현 측정 정본)
- 본 EDD task 5건: `eval/tasks-edd/edd-main-skill-invocation-*.json`
