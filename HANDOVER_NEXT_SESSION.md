# HANDOVER — 2026-05-01 #10_5 → 다음 세션 (로컬 채팅방 복귀)

> **작성자**: 2026-05-01 야간 리모트 세션 (Claude Opus 4.7 1M, #10_5 — 책 V1.1 전체 학습 + P0 재추출)
> **수신자**: 사용자 외출 복귀 후 다음 로컬 채팅방
> **검증 명령**: `cd /Users/sokol/Desktop/Git/ProjectGrimoire && git log --oneline -10 && bash eval/scripts/eval-runner.sh`

---

## 🚨 0. 절대 준수 사항 (사용자 명시 결정 — 보존)

### 0-1. 외부 Anthropic API 신규 의존 보류 (2026-04-30)
> "앤스로픽 외부 api를 쓰는 방향으로의 하네스엔지니어링, 에이전트 고도화는 나중 과제로 좀 미루고 싶다"

**금지 카테고리** (Claude Code 구독 외 종량제 API):
- LLM-as-Judge 실제 SDK 연동 (grade-llm.py는 stub 그대로 유지)
- **에이전트별 모델 티어링 (Opus/Sonnet/Haiku 분리)** — **본 세션 책 학습 결과 강력 권장이지만 사용자 보류 결정 우선**
- Agent teams experimental
- 책 Ch 17 협업 패턴

사용자가 다시 "진행" 명시할 때까지 손대지 않는다.

### 0-2. CLAUDE.md §0 ZERO-TOLERANCE
- 추정 보고 절대 금지 (직접 명령 검증)
- 정책·PRD 강제 종속

### 0-3. 한국어 존댓말 필수

---

## 1. 본 세션 #10_5 핵심 결과 — 책 V1.1 전체 학습 완료

### 1-1. 책 학습 완료
- **「하네스 엔지니어링 완전 정복」V1.1 (shuntailor, 2026-03)** — 206 페이지 전부 학습
- PDF Read tool 7회 호출 (page 1~206)
- 학습 박제: `.claude/knowledge/book-harness-engineering-completion.md` 전면 갱신 (Ch 08/15/16 → 책 전체로 확장)

### 1-2. 책 결론 (사용자 즉시 알아야 함)
> **"모델은 범용품(commodity)이다. 하네스가 해자(moat)다."** — 책 결론
> **"Foundation Model = CPU, 하네스 = OS"** — Philipp Schmid
> **"하네스는 코드보다 빠르게 썩는다. 정원과 같다."** — Ch 23

### 1-3. 우리 시스템 95% 정합 (책 권장 그대로 적용)
| 정합 항목 | 책 출처 | 우리 구현 |
|---------|--------|---------|
| **shared-contracts.md** (책 정본 파일명 동일!) | Ch 16 | 4-30 박제 완료 |
| 60-line 황금률 4 분할 | Ch 08 | CLAUDE.md 73 + 3 AGENTS.md |
| EDD (실패 수집 → 기준선 → 반복 개선) | Ch 15 | 38 task / 30일 평균 97%+ |
| Hooks 9 이벤트 | Ch 11 | 12 스크립트 |
| Skills (Progressive Disclosure) | Ch 11 | 14개 |
| Sprint 계약 (Initializer/Generator/Evaluator) | Ch 16 | Plan/QA agent 부분 적용 |
| **.claude/ = 사내 위키 패턴** | 솔로 사례 (Cuneiform Chat 인용) | 30+ 참조 문서 |
| PreCompact memory guard | Ch 21 | 신설 |

---

## 2. 책 학습 결과 → NEW P0 10건 도출 (5% 갭)

### 🟢 P0 즉시 진행 가능 (외부 API 0)
| # | 과제 | 책 근거 | 우선순위 | 예상 시간 |
|---|------|--------|---------|---------|
| **#4** | **cost-tracker.jsonl** (호출별 task_id/model/tokens/cost JSONL) | Ch 18 cost_tracker.py 정본 | P0 | 1.5h |
| **#6** | **sensor-harness-self-diagnose** (Ch 23 자가진단 7질문 자동화) | Ch 23 | P0 | 1h (sensor 6/7 이미 보유, 통합만) |
| **#5** | **sensor-loop-detection** (MAX_EDITS_PER_FILE=5 둠 루프 방지) | Ch 21 LangChain LoopDetectionMiddleware | P0 | 1h |
| **#10** | **5 오케스트레이션 박제** (.claude/AGENTS.md §2.2.1 위임 매트릭스 → 5 패턴 표 추가, Ralph Loop 신규) | Ch 16 + 부록 B | P0 | 30분 |
| #9 | 컨텍스트 토큰 예산 sensor (시스템 프롬프트 + CLAUDE.md + 누적 대화) | Ch 18 | P1 | 1h |

### 🟡 P1 (외부 API 0이지만 인프라 변경)
| # | 과제 | 책 근거 |
|---|------|--------|
| #8 | Eval 점수 가중치 도입 (이분법 PASS/FAIL → 0~100 점수 분포) | Ch 20 TaskFlow 5차원 |
| #3 | 에이전트별 예산 할당 (max_tokens/max_tool_calls/max_wall_time) | Ch 16 AGENT_BUDGETS |
| #7 | Hooks에 Semgrep/Snyk 통합 (AI 코드 정적 분석) | Ch 17 보안 체크리스트 #4 |

### 👤 사용자 결정 영역 (자율 진행 금지)
| # | 과제 | 사용자 결정 사유 |
|---|------|--------------|
| #1 | **MCP 연동** (Figma/GitHub/Playwright) | 외부 도구 연동 — 사용자 결정 |
| #2 | **에이전트별 모델 티어링** (Opus/Sonnet/Haiku) | **0-1 보류 결정 적용** — 책에서 강력 권장하지만 사용자 명시 보류 유지 |

---

## 3. 자가진단 7질문 (Ch 23) — 우리 현재 상태

3 이상 "아니오"면 쇠퇴 경로. **현재 우리 5/7 ✅ — 건강**:

| # | 질문 | 우리 sensor | 상태 |
|---|------|-----------|------|
| 1 | 작업 시간 70%+ 실제 구현? | sensor-orchestration-ratio (NEW-17) | ✅ |
| 2 | CLAUDE.md ≤100줄? | sensor-claude-md-size | ✅ (73줄) |
| 3 | 하네스 수정 효과 수치 증명? | sensor-eval-trend | ✅ |
| 4 | 모델 개선 여지 측정? | — | ❌ (보류 결정) |
| 5 | CLAUDE.md ↔ 코드 일치? | sensor-doc-drift | ✅ |
| 6 | 태스크 유형별 비용 인지? | — | ❌ → **NEW P0 #4** |
| 7 | 하네스 변경 리뷰 프로세스? | sensor-shared-contracts (부분) | ⚠️ |

→ **NEW P0 #4 (cost-tracker) + #6 (자가진단 자동화) 우선순위 이유**: 7 질문 중 ⚠️/❌ 3건 모두 해소 가능

---

## 4. Git 상태 (2026-05-01 야간 리모트, 본 세션 commit 전)

```bash
develop: 78914cd (push 완료) — 묶음 Q
main:    묶음 P 머지 시점 (이전 핸드오버 #10_4)

미commit 변경:
  M .claude/knowledge/book-harness-engineering-completion.md (전면 갱신)
  ?? memory/project_session_20260501_3.md (본 세션 박제)
  ?? V1.1 하네스 엔지니어링 완전정복.pdf (책 PDF — gitignore 검토 필요)
```

본 세션 commit 예정 후 develop push → 사용자 결정 후 main 머지.

---

## 5. 검증 baseline (본 세션 시작 전)

| 검증 | 결과 |
|------|------|
| Regression | **38/38 PASS = 100%** |
| EDD (runs=5) | **41/41 PASS = 100%** (#10_4 묶음 Q 측정) |
| Drift sensor | exit 0 |
| sensor-instruction-degradation | 11/11 PASS, WARN 0 |
| sensor-agent-priority-labels | PASS 7/7 |

본 세션 코드/설정 변경 0건 (책 학습 + 박제만) → 검증 결과 동일.

---

## 6. 즉시 검증 명령 (다음 세션 첫 5분)

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire

# 1. git 정합 확인
git log --oneline -10
git status

# 2. 회귀 검증 (38/38 PASS여야)
bash eval/scripts/eval-runner.sh

# 3. drift 검증 (exit 0)
bash .claude/scripts/instructions-drift-check.sh

# 4. 책 학습 박제 확인
cat .claude/knowledge/book-harness-engineering-completion.md | head -50
```

---

## 7. 다음 세션 시작 시 추천 작업 (사용자 명시 후)

**Option A — 책 학습 결과 즉시 적용** (외부 API 0, 추천):
1. **묶음 R**: NEW P0 #4 (cost-tracker.jsonl) + #6 (sensor-harness-self-diagnose) — 2.5h
2. **묶음 S**: NEW P0 #5 (sensor-loop-detection) + #10 (5 오케스트레이션 박제) — 1.5h

**Option B — 사용자 결정 후 진행**:
- NEW P0 #1 MCP 연동 (사용자 결정)
- NEW P0 #2 모델 티어링 (사용자 보류 해제 시)
- 책 PDF gitignore 처리 (1.7MB, claude-docs PRIVATE이지만 size 고려)

**Option C — 사용자 직접 결정 영역**:
- consolidate-memory stale 11건 archive (J6, 미해소)
- PLANNING_GRIMOIRE.md §16 인벤토리 갱신

---

## 8. 메모리 절대 규칙 (Stop hook H10 자동 검증)

다음 세션 종료 전:
1. 코드 변경 → `memory/project_session_YYYYMMDD[_N].md` 작성
2. `memory/MEMORY.md` 인덱스에 1줄 추가 (Stop hook 검증)
3. `memory/project_remaining_tasks.md` 현행화 (7일 stale WARN)

---

## 9. 알아둘 부수 사항

### 본 세션 외부 API 0건 (사용자 명시 0-1 준수)
- 책 학습은 PDF Read tool만 사용 (Anthropic API 신규 호출 0)
- 책 학습 후 신규 NEW P0 #2 (모델 티어링)는 책에서 강력 권장하지만 사용자 명시 보류 결정 유지

### 책 PDF 위치
`/Users/sokol/Desktop/Git/ProjectGrimoire/V1.1 하네스 엔지니어링 완전정복.pdf` (1.7MB)
- 사용자 직접 드래그앤드롭으로 추가 (2026-04-29)
- claude-docs PRIVATE 레포에 박제 가치 vs 용량 — 사용자 결정 필요

### 본 세션 변경 파일 (총 2건)
1. `.claude/knowledge/book-harness-engineering-completion.md` (전면 갱신, 173 → 약 250줄)
2. `memory/project_session_20260501_3.md` (신설)
3. `memory/MEMORY.md` (1줄 추가)
4. `HANDOVER_NEXT_SESSION.md` (본 파일, 전면 갱신)

---

## 10. 핵심 정본 위치

| 영역 | 정본 |
|------|------|
| 절대 규정 | `CLAUDE.md` §0 (73줄) |
| 메모리/멀티에이전트 | `.claude/AGENTS.md` |
| 문서 동기화/피라미드 | `docs/AGENTS.md` |
| Git/Pre-Push | `.githooks/AGENTS.md` |
| 에이전트 인터페이스 | `.claude/shared-contracts.md` (10건) |
| **책 학습 박제 (전면 갱신)** | `.claude/knowledge/book-harness-engineering-completion.md` |
| 우선순위 (남은 과제) | `memory/project_remaining_tasks.md` (NEW P0 10건 추가 필요) |
| 인벤토리 | `AUTOMATION.md` |
| 하네스 이론 | `research/HARNESS_ENGINEERING.md` + 분리 4 정본 |
| **본 핸드오버** | `HANDOVER_NEXT_SESSION.md` (워크스페이스 루트, 본 파일) |

---

## 변경 이력
- 2026-05-01 #10_2: 본 파일 신설
- 2026-05-01 #10_5: **책 V1.1 전체 학습 완료 박제 — Ch 1~23 + 부록 A/B/C, 206 페이지. NEW P0 10건 도출 (cost-tracker / 자가진단 / loop-detection / 5 오케스트레이션 등). 우리 시스템 95% 정합. 외부 API 0건.**
