# HANDOVER — 2026-05-02 #10_6 (묶음 W+X+Y+Z 추가) → 다음 세션

> **작성자**: 2026-05-02 로컬 세션 (Claude Opus 4.7 1M, #10_6 — 4 + 4 = 8 묶음 자율 진행)
> **수신자**: 다음 세션 (로컬/리모트)
> **검증 명령**: `cd /Users/sokol/Desktop/Git/ProjectGrimoire && git log --oneline -10 && bash eval/scripts/eval-runner.sh`
>
> **핵심**: 적대적 검증 시스템 도입 완료 — Red Team Constitution 16 Principles + Socratic Self-Critique + Bounded Retry + 자율학습 3단 분리 (모두 외부 API 0).

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

## 1. 본 세션 #10_6 핵심 결과 (총 8 묶음 자율 진행)

### 묶음 W+X+Y+Z (적대적 검증 시스템 — 사용자 지시 후속)
- **묶음 W (`fd63509`)**: red-team-constitution.md 16 principles + sensor-adversarial-pre-commit.sh + .githooks/pre-commit [4/4] 강화
- **묶음 X (`d43ed90`)**: socratic-self-critique skill (Q00/ouroboros Two-diamond + Constitutional AI 차용)
- **묶음 Y (`fc18049`)**: adversarial-retry-handler.sh (max 2 iterations, ng/adversarial-review 정합)
- **묶음 Z (`250cb5a`)**: 자율학습 3단 분리 — red-team-data-collector.sh + sensor-red-team-source-whitelist.sh + red-team-update-propose skill + proposals/ 게이트

### 1.5 책 V1.1 학습 박제 (research)
- **HARNESS_ADVERSARIAL_VERIFICATION.md** (`9788afd` + `e14dc51`): 우로보로스 + 악마의 변호인 + 레드팀 적용 리서치 (374줄, 출처 17개) + §5.5 자율학습 평가

### 묶음 R+S+T+V' (이전 사용자 위임 자율 진행)

사용자 위임 (피곤 상태): "최대한 많은 묶음을 컨텍스트 rot 없이 두 번 작업할 일 없이 작업순서를 정하고 진행" → 4 묶음 자율 commit.

### 묶음 R (`88996c4`) — 책 Ch 23 자가진단 갭 해소
- BN-#4: cost-tracker.sh 신설 (호출별 JSONL 박제 + log/report/estimate 명령)
- BN-#6: sensor-harness-self-diagnose.sh 신설 (Ch 23 7질문 자동화)
- 효과: Q6 ❌→✅ + 안티패턴 #6 비용 블랙홀 영구 방어

### 묶음 S (`cc57c8a`) — 책 Ch 21 Correct + Ch 16 패턴
- BN-#5: loop-detection-tracker (PostToolUse Edit|Write 자동 박제) + sensor-loop-detection (MAX_EDITS_PER_FILE=5)
- BN-#10: .claude/AGENTS.md §2.2.2 5 오케스트레이션 패턴 박제 (Ralph Loop 신규)

### 묶음 T (`c4e1653`) — 책 Ch 16 + Ch 18
- BN-#3: .claude/AGENTS.md §2.4 7 에이전트 AGENT_BUDGETS 박제 (옵션 C — 7 에이전트 .md 0 변경)
- BN-#9: sensor-context-budget.sh (베이스라인 + 전체 분할 + 7 에이전트 토큰 추정)

### 묶음 V' (`0cc5d44`) — 자가진단 Q7 ⚠️→✅
- NEW-B: sensor-shared-contracts §4 변경 리뷰 프로세스 강화 (90일 stale + 7 에이전트 mtime 동기)
- NEW-C: sensor-harness-cross-ref (#10_4 묶음 L 분리 4정본 cross-ref 검증)

### 자가진단 진화
- 묶음 시작 전: PASS 3 / FAIL 2 (Q6/Q7) / SKIP 1 (Q4)
- 묶음 종료 후: **PASS 5 / FAIL 1 (Q1 별도 P1) / SKIP 1 (Q4)** — 책 Ch 23 건강 영역 강화

---

## 1.5 [구 #10_5] 책 V1.1 전체 학습 완료 (참조 보존)

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

## 4. Git 상태 (2026-05-02 #10_6 종료, 8 묶음 + research/ 박제 commit/push 완료)

```bash
develop: 250cb5a (push 완료) — 묶음 Z 자율학습 3단 분리
main:    78914cd (이전 머지 시점, 묶음 Q)

develop이 main + 16 commit 앞섬 (#10_5 + #10_6 누적):
  250cb5a 묶음 Z (Phase ε) — 자율학습 3단 분리 (사용자 추가 요구)
  fc18049 묶음 Y (Phase γ) — Bounded Retry Loop (max 2)
  d43ed90 묶음 X (Phase β) — Socratic Self-Critique Skill
  fd63509 묶음 W (Phase α) — Red Team Constitution 16 Principles + adversarial sensor
  6f44866 sensor-server Jest flaky 회복탄력성
  e14dc51 HARNESS_ADVERSARIAL_VERIFICATION §5.5 자율학습 평가
  9788afd HARNESS_ADVERSARIAL_VERIFICATION.md 신설 (우로보로스 + 악마의 변호인 + 레드팀)
  caa7361 Hook 스크립트 13→14 정합
  fd2c75f #10_6 R+S+T+V' 박제
  ... (R/S/T/V' 4건)
  ... (이전 #10_5 정합)
  0cc5d44 묶음 V' — NEW-B sensor-shared-contracts §4 + NEW-C harness-cross-ref
  c4e1653 묶음 T — BN-#3 에이전트 예산 + BN-#9 context-budget
  cc57c8a 묶음 S — BN-#5 loop-detection + BN-#10 5 오케스트레이션
  88996c4 묶음 R — BN-#4 cost-tracker + BN-#6 self-diagnose
  80e2645 우선처리 — gitignore lock + HANDOVER 38→41 정합
  dc0a09e #10_5 git 상태 정확 반영
  3893c5b 책 V1.1 전체 학습

본 세션 미commit (사용자 결정 영역):
  ?? V1.1 하네스 엔지니어링 완전정복.pdf (1.7MB)
```

**main 머지 가능 여부**: 7 commit, 100% 비파괴적 (sensor/script/문서 박제만, server·web·db 0 변경). 사용자 명시 후 안전 머지 가능.

---

## 5. 검증 baseline (본 세션 #10_6 종료 시점, 8 묶음 누적)

| 검증 | 결과 |
|------|------|
| Regression | **48/48 PASS = 100%** (#10_6 8 묶음 누적: +8 sensor wrap) |
| EDD | 의도된 갭 유지 (edd-031/edd-033) |
| Drift sensor | exit 0 |
| sensor-instruction-degradation | 11/11 PASS, WARN 0 |
| sensor-agent-priority-labels | PASS 7/7 |
| sensor-harness-self-diagnose (Ch 23) | PASS 5 / FAIL 1 (Q1 ratio P1) / SKIP 1 (Q4 사용자 보류) |
| sensor-shared-contracts §4 강화 | PASS (90일 stale + mtime 동기) |
| sensor-harness-cross-ref | PASS (분리 5정본 정합 — ADVERSARIAL_VERIFICATION 추가) |
| **sensor-adversarial-pre-commit (16 Principles)** | **PASS 13 / WARN 3 / FAIL 0** (P1 commit 패턴 / P4 cost-margin 조기 / P16 CreditLog audit) |
| **sensor-red-team-source-whitelist** | PASS (whitelist 정합 / 차단 정합) |
| Skills 22 / Sensors 25 / Hooks 10이벤트 14스크립트 / Knowledge 8 / Agents 7 | 정합 |

---

## 6. 즉시 검증 명령 (다음 세션 첫 5분)

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire

# 1. git 정합 확인
git log --oneline -10
git status

# 2. 회귀 검증 (41/41 PASS여야 — 의도된 EDD-only 갭은 tasks-edd/만 영향)
bash eval/scripts/eval-runner.sh

# 3. drift 검증 (exit 0)
bash .claude/scripts/instructions-drift-check.sh

# 4. 책 학습 박제 확인
cat .claude/knowledge/book-harness-engineering-completion.md | head -50
```

---

## 7. 다음 세션 시작 시 추천 작업 (사용자 명시 후)

**Option A — 적대적 시스템 안정화 + 자율학습 시범 운영** (외부 API 0):
1. **묶음 AA**: sensor-adversarial-pre-commit WARN 3건 해소 — 1h
   - P1 commit 패턴 false positive 정밀화
   - P4 cost-margin 조기 경보 추적
   - P16 CreditLog audit 보강 (server 도메인 — 사용자 결정)
2. **묶음 BB**: 자율학습 시범 운영 — 1주 후 첫 propose 생성
   - red-team-data-collector add (5건 whitelist 출처 박제)
   - red-team-update-propose 첫 호출 → proposals/ 박제
   - 사용자 검토 후 적용 결정

**Option B — 자가진단 Q1 정밀화 + Eval 점수 가중치** (외부 API 0):
- sensor-orchestration-ratio 정밀도 강화 (Q1 FAIL 해소) — 1h
- BN-#8 Eval 점수 가중치 (이분법 → 0~100 5차원, 책 Ch 20 TaskFlow) — 2h

**Option C — 사용자 직접 결정 영역 (자율 진행 금지)**:
- **NEW P0 #1 MCP 연동** (Figma/GitHub/Playwright)
- **NEW P0 #2 모델 티어링** (Opus/Sonnet/Haiku, 책 40~60% 절감 강력 권장 vs 0-1 보류)
- **NEW-A**: EDD 의도된 갭 2건 해소 (server·web 코드 변경 동반)
- **J8**: claude-docs develop → main 머지 (현재 + 16 commit, 100% 비파괴적)
- **PDF**: V1.1 하네스 엔지니어링 PDF (1.7MB) gitignore vs 박제 결정
- **proposals/{date}.md** 적용 (자율학습 결과 — 각 proposal 사용자 명시 후만)

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
