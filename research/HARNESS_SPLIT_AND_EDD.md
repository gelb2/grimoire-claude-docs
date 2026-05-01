# Harness Engineering — CLAUDE.md 분할 정본 + EDD (분리 정본, 2026-05-02 묶음 L M3)

> **분리 사유**: `research/HARNESS_ENGINEERING.md` §17 (책 Ch 08+15+16 박제) 50줄을 별도 정본으로 분리. § 번호 그대로 유지 (§17). 2026-04-30 #10 세션 결정사항 박제.
>
> **참조하는 파일**:
> - `HANDOVER_NEXT_SESSION.md` (2026-05-01 #10_2 인계)
> - `.claude/knowledge/book-harness-engineering-completion.md`
> - `.claude/skills/eval-run/SKILL.md` (EDD 컨텍스트)
>
> **원본 위치**: `research/HARNESS_ENGINEERING.md` §17 (2026-04-30 신설 → 2026-05-02 본 파일로 분리).

---

## 17. CLAUDE.md 60줄 분할 + 에이전트 인터페이스 정본 (2026-04-30 세션 #10 신설)

> **근거**: 책 「하네스 엔지니어링 완전 정복」 Ch 08 (60줄 황금률) + Ch 16 (멀티 에이전트 shared contracts) + Ch 15 (LLM-as-Judge + EDD).
> **HumanLayer 발견**: 50개 룰 → 절반 무시, 100개 룰 → 우선순위 상실. CLAUDE.md 22.8KB → instruction-degradation 명백.

### 17.1 분할 구조 (4 파일)

| 파일 | 역할 | 줄수 (실측) |
|------|------|------------|
| `CLAUDE.md` (root) | boost: §0 절대규정 + §1 프로젝트 + §2 공통 규칙 + §7 환경 + §9/13 pointer + §15 프롬프트 정본 | 73 |
| `.claude/AGENTS.md` | 하네스 레이어: §12 메모리 절대규칙 + §14 멀티에이전트 + §15 프롬프트 정본 + 인벤토리 검증 | 114 |
| `docs/AGENTS.md` | 문서 레이어: §3 동기화 + §4 레포 구조 + §5 피라미드 + §6 워크플로우 + §11 전수검사 | 195 |
| `.githooks/AGENTS.md` | Git/CI 레이어: §8 브랜치 + §10 Pre-Push (server/web 실제 hook 본문 박제) | 125 |

총 507줄 — 단일 CLAUDE.md(457줄) 대비 +50줄. 분할로 attention degradation 회피 + AGENTS.md 자동 자식 디렉토리 로드(Claude Code 표준).

### 17.2 shared-contracts.md (책 Ch 16)

`.claude/shared-contracts.md` (NEW, 11.4KB): 7개 에이전트가 주고받는 인터페이스 10개 정본 박제.
- PLANNER_REPORT / COST_AUDIT_REPORT / VISUAL_CANON_REPORT / DEV_REPORT / QA_REPORT (with §3 Eval results)
- AskOptions (signal: AbortSignal)
- ANALYSIS_CREDIT_COST = 4
- Eval task format
- LLM-as-Judge cost guard
- PostToolUseFailure hook policy

각 에이전트(.md 7개)는 §0 박제 직후 `.claude/shared-contracts.md` 참조 1줄 주입. 인터페이스 변경 시 shared-contracts.md 먼저 갱신 → 7개 에이전트 동시 동기화.

### 17.3 LLM-as-Judge (책 Ch 15) + EDD 모드 추가

- **`eval/scripts/grade-llm.py`** (NEW): cost-accountant 7번째 위임 결과 박제. Daily ₩2,000 alert / Monthly ₩50,000 cap / per-call ~₩20 estimate (Sonnet 4.6, 2K input + 0.5K output)
- **EDD 모드** (`eval/scripts/eval-runner.sh --mode=edd`): runs=10 default + category별 threshold (security/cost_zero 0.95+, visual_canon 0.90+, author_content 1.00, ...)
- **EDD 전용 task**: `eval/tasks-edd/` 분리 (regression mode가 LLM 타입을 모르므로)

### 17.4 검증 결과 (2026-04-30)

| 검증 | 명령 | 결과 |
|------|------|------|
| Drift 0건 | `bash .claude/scripts/instructions-drift-check.sh` | exit 0 |
| Regression 100% | `bash eval/scripts/eval-runner.sh` | 20/20 PASS |
| EDD 100% | `bash eval/scripts/eval-runner.sh --mode=edd --runs=2` | 21/21 PASS |
| 분할 줄수 | `wc -l CLAUDE.md .claude/AGENTS.md docs/AGENTS.md .githooks/AGENTS.md` | 73+114+195+125 |

### 17.5 향후 진화

- **P1**: shared-contracts.md drift sensor 신설 — 인터페이스 변경 누락 자동 감지
- **P2**: LLM-as-Judge 실제 Anthropic SDK 연동 (현재 stub) + 일별 비용 대시보드
- **P3**: 책 Ch 17 "에이전트 협업 패턴" 검토 (orchestration_ratio 기반 자동 위임)


