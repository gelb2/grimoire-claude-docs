# 「하네스 엔지니어링 완전 정복」(shuntailor 2026-03) 학습 박제

> ProjectGrimoire 도입 챕터 핵심 정리. 다음 세션에서 빠르게 참조용.
> 박제 일자: 2026-04-30 #10. 현 적용 상태: Ch 08 ✅ / Ch 15 ✅ / Ch 16 ✅.

---

## Ch 08 — 60-line 황금률 (HumanLayer 발견)

### 핵심 발견
- 50개 룰 → 절반 무시
- 100개 룰 → 우선순위 상실
- 단일 instruction 파일이 60줄 초과 시 instruction degradation 시작

### 적용 패턴
- root `CLAUDE.md`: ~60줄, 절대 규정 + pointer만
- 자식 디렉토리에 `AGENTS.md` 분할 (자동 로드)
- 분할 기준: 도메인 응집성 (memory/agent / docs / git/CI)

### ProjectGrimoire 적용 (2026-04-30 #10)
| 파일 | 줄수 | 영역 |
|------|------|------|
| `CLAUDE.md` | 73 | boost (§0 절대규정 + pointer) |
| `.claude/AGENTS.md` | 114 | 하네스 (메모리 + 멀티에이전트) |
| `docs/AGENTS.md` | 195 | 문서 (동기화 + 피라미드 + 전수검사) |
| `.githooks/AGENTS.md` | 125 | Git/CI (브랜치 + Pre-Push) |

### 주의
- 분할 자체가 목적 X — 응집성 있는 도메인 단위로 분할해야 의미 있음
- 분할 후 cross-reference 정합성 필수 (각 AGENTS.md → root CLAUDE.md → 다른 AGENTS.md)
- 자동 검증: `sensor-instruction-degradation.sh` (2026-04-30 #10 묶음 C 신설)

---

## Ch 15 — Eval-Driven Development (EDD)

### TDD vs EDD
| 차원 | TDD | EDD |
|------|-----|-----|
| 목적 | 결정적 동작 검증 | 확률적 동작 평가 |
| 실행 | 1회 | N회 (보통 10) |
| 임계값 | 1.0 (전 통과) | 카테고리별 (0.65~1.0) |
| 적용 | 함수/메서드 | LLM 응답 / AI 에이전트 |

### EDD 6 단계 (책 권장)
1. **Define**: eval 기준을 코드 짜기 전에 먼저 정의
2. **Baseline**: 현재 시스템의 통과율 측정 (기준선)
3. **Iterate**: 코드 변경 → eval 재실행 → 통과율 비교
4. **Threshold**: 카테고리별 통과율 기준 (security 0.95+, edge_case 0.75 등)
5. **Regression**: 새 변경이 기존 통과율 떨어뜨리지 않는지 자동 차단
6. **LLM-as-Judge** (옵션): 주관 평가 영역에 LLM 위임 (외부 API 비용 동반)

### ProjectGrimoire 적용 (2026-04-27 #9 + 2026-04-30 #10)
- `eval/scripts/eval-runner.sh --mode=edd` (runs=10 default + category thresholds)
- `eval/scripts/grade.py` — 코드 기반 채점 (grep / grep_count / command / inventory_match)
- `eval/scripts/grade-llm.py` — LLM 채점 (현재 stub, 사용자 명시 보류)
- `eval/tasks/` 27 task + `eval/tasks-edd/` 1 sample
- `eval/scripts/generate-sensor-tasks.sh` — sensor → task 자동 wrap (2026-04-30 #10 F1)

### 카테고리별 임계값 (cost-accountant 권장)
| 카테고리 | 임계값 | 이유 |
|----------|--------|------|
| author_content | 1.00 | 작가 본문 보호 — 무관용 |
| security / cost_zero | 0.95+ | 실패 1건 비용 극도 / §0 위반 |
| visual_canon / type_safety | 0.90+ | 사슴악마 정본 / 코드 결정적 |
| convention / api_contract | 0.85 | 코드 스타일 |
| edge_case | 0.75 | 경로 다수 |
| test_coverage | 0.65 | 부분 성공 가치 |

### LLM-as-Judge 비용 가드 (필수)
- per-call ~₩20 (Sonnet 4.6, 2K input + 0.5K output)
- Daily alert ₩2,000 (100회/일)
- Monthly cap ₩50,000 (~$35/월, 자동 차단)
- LLM 태스크 비율 ≤ 35% (20개 중 7개 이하 권장)

---

## Ch 16 — Multi-Agent Shared Contracts

### 문제
- 7개 에이전트가 각자 자기 .md에 인터페이스 박제 → drift 누적
- 한 에이전트가 인터페이스 변경 → 다른 6개 에이전트 .md 수동 동기화 필요 → 누락 발생

### 해결: 정본 1곳 + 모든 에이전트가 동기 참조
- `.claude/shared-contracts.md` (root only) 단일 정본
- 7개 에이전트 .md는 §0 직후 1줄 참조: `> 인터페이스 정본은 .claude/shared-contracts.md 참조`
- 인터페이스 변경 시 shared-contracts.md 먼저 갱신 → 7개 .md는 자동 정합

### shared-contracts.md 10 인터페이스 (2026-04-30 #10 박제)
1. PLANNER_REPORT (planner → server/web)
2. COST_AUDIT_REPORT (cost-accountant → planner/server/web/qa)
3. VISUAL_CANON_REPORT (visual-canon-keeper → web/qa)
4. DEV_REPORT (server + web → qa)
5. QA_REPORT (qa → 사용자, with §3 Eval results)
6. AskOptions (server 도메인 — Anthropic SDK signal 시그니처)
7. ANALYSIS_CREDIT_COST = 4 (server 도메인)
8. Eval task 형식 (eval 시스템)
9. LLM-as-Judge 비용 가드 (eval 시스템)
10. PostToolUseFailure hook 정책 (Chrome MCP F2)

### 자동 검증 sensor (2026-04-30 #10 묶음 A 신설)
- `sensor-shared-contracts.sh` — 7 에이전트 .md ↔ shared-contracts.md 동기 참조 + 10 인터페이스 코드 박제 자동 검증
- 변경 누락 시 InstructionsLoaded hook 단계에서 차단

---

## 미적용 / 보류 챕터

### Ch 17 — 에이전트 협업 패턴
- 실험적 agent teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- 외부 모델 호출 가능성 → 사용자 명시 보류 (2026-04-30)

### LLM-as-Judge 실제 SDK 연동
- `grade-llm.py`는 현재 stub (인프라 + 가드만)
- 실제 anthropic SDK 호출은 사용자 명시 보류 (Claude Code 구독료와 별개 종량제)

---

## 적용 패턴 정합 검증

| 패턴 | 검증 방법 | sensor |
|------|----------|--------|
| 60-line 황금률 | 분할 4파일 줄수 ≤ 임계값 | sensor-instruction-degradation (2026-04-30 #10 신설) |
| EDD 회귀 | regression 100% / EDD ≥ category threshold | eval-runner.sh |
| shared-contracts 정합 | 7 agents 동기 참조 + 10 인터페이스 박제 | sensor-shared-contracts |

---

## 변경 이력
- 2026-04-30: 본 파일 신설 — 책 Ch 08/15/16 핵심 학습 박제 (묶음 C D1 작업).
