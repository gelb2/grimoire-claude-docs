# PAYMENT_READINESS_AUDIT — 결제 기능 즉시 구현 가능 상태 종합 점검

> **작성**: 2026-05-03 #10_7 자율 점검
> **트리거**: 사용자 요구 — "결제기능 구현 제대로 할 수 있게 모든 문서/에이전트/하네스/문서간 참조/레드팀/CERTI_PROJ 파악 내용 다 점검"
> **결론 한 줄**: **결제 PAY-P0/P1 즉시 착수 가능 상태입니다**. 갭 5건 식별 (모두 사용자 승인 후 보강 권고 — 자율 차단 사유 0건).

---

## 0. 종합 판정

| 영역 | 상태 | 갭 |
|---|---|---|
| sensor (레드팀 + 원가 + 시크릿) | ✅ PASS | 1건 (sensor-credit-atomicity false positive) |
| 정본 문서 (PAYMENT_SYSTEM_PLAN ↔ PLANNING ↔ server docs) | ✅ PASS | 1건 (DOC_MAP.html cross-ref 부재) |
| shared-contracts | ✅ PASS | 1건 (PAY P0 진행 시 §11+ 신설 필요 — 사전 조건) |
| 에이전트 7개 결제 책임 | ⚠️ 부분 | 2건 (web/qa .md 결제 명시 부재) |
| 하네스 (skills/eval/knowledge/hooks) | ✅ PASS | 0건 |
| CERTI_PROJ 박제 | ✅ PASS | 0건 |

→ **즉시 차단 사유 0건**. PAY-P0 (~7h) 사용자 명시 후 진행 가능.

---

## 1. Sensor 실측 결과 (레드팀 + 원가 + 시크릿)

### 1-1. sensor-credit-atomicity (결제 원자성 강제)

```
PASS: 3 / FAIL: 0 / WARN: 1
[PASS] payment+credit repository $transaction — payment 1 건 + credit 2 건 (Hexagonal 정합)
[WARN] CreditLog audit trail — creditLog.create 호출 0 건 — audit trail 부재 가능성
[PASS] 분석 환불 분기 — refund/abortableRace 10 건, catch 2 블록
[PASS] Polar webhook secret env 강제 — webhook secret 하드코딩 0 건
```

**WARN 분석**: false positive입니다. 실제 코드에는 `prisma-payment.repository.ts:35`에서 `tx.creditLog.create(...)` 호출이 명백히 존재하는데, sensor의 grep 패턴이 검출 못함. **sensor 패턴 정밀화 필요** (별도 추가 항목).

### 1-2. sensor-cost-margin (§0 원가 철칙)

```
분석 대상: grimoire-server/docs/ai-cost-table.md
안전배수 항목 수: 18
  최소: 3.23× / 평균: 3.74× / 최대: 5.93×
  3.0× 미만 (FAIL): 0 건
  3.0~3.5× (WARN): 8 건
판정 컬럼: PASS 12 / FAIL 0
```

**8건 WARN**: 모두 3.0~3.5× 안전배수 (조기 경보, 책 Ch 18 cost-accountant 권장 임계). adversarial sensor에서 **ACCEPTABLE 마크** 처리. `ai-cost-table.md` 6일 stale (재계산 임계 미만).

### 1-3. sensor-adversarial-pre-commit (Constitution 19 Principles)

```
PASS: 17 / WARN: 2 / FAIL: 0 (총 19)

결제 관련 Principle 직접 평가:
✅ P3  작가 콘텐츠 보호 — 본문 수정 패턴 0건
⚠️ P4  §0 원가 철칙 (마진 ≥3.5×) — WARN ACCEPTABLE (조기 경보)
✅ P5  외부 Anthropic API 보류 — anthropic SDK import 0건
✅ P11 Git main 직접 commit 금지
✅ P12 Pre-push hook 우회 금지
✅ P13 시크릿 평문 금지 — sensor-secret-leak PASS
✅ P14 BFF 프록시 강제 — 백엔드 URL 직접 호출 0건
✅ P15 HttpOnly Cookie 강제 — localStorage 토큰 저장 0건
⚠️ P16 결제 원자성 (transaction) — WARN ACCEPTABLE (1-1 false positive 동일)
✅ P17 LLM Prompt Injection 방어
✅ P18 LLM Output Encoding
✅ P19 Sensitive Info Disclosure
```

**모든 결제 관련 Principle PASS 또는 ACCEPTABLE** — 레드팀 게이트 즉시 통과 가능.

### 1-4. sensor-shared-contracts (인터페이스 drift)

```
✅ AskOptions (signal: AbortSignal) 박제 — claude.ts
✅ ANALYSIS_CREDIT_COST = 4 박제 — config.ts
✅ Eval task 형식 (eval_criteria) 박제 — 51 task
✅ LLM-as-Judge 비용 가드 (₩2K/₩50K) 박제
✅ PostToolUseFailure hook 등록
✅ shared-contracts.md mtime 1일 (90일 임계 이내)
✅ 에이전트 변경 동기 정합 (0/7 미갱신)
```

**drift 0** — 결제 인터페이스 변경 시 7 에이전트 자동 동기화 가능 상태.

### 1-5. sensor-secret-leak

```
=== 결과 ===
FAIL (위반): 0 건
WARN (의도된 위치): 0 건
[RESULT] PASS — 모든 git tracked 파일 클린.
```

**Polar webhook secret / API key 등 시크릿 모두 환경변수 전용** (P13 PASS).

---

## 2. 정본 문서 정합 점검

### 2-1. 결제 정본 박제 위치 (실측)

| 문서 | 위치 | 결제 관련 내용 |
|---|---|---|
| `PLANNING_GRIMOIRE.md` §0 | 워크스페이스 루트 (정본) | 크레딧-원가 철칙 + Polar 결제 수수료 + 마진 ≥3× |
| `PLANNING_GRIMOIRE.md` §8 | 워크스페이스 루트 (정본) | 크레딧 시스템 + Polar 흐름 + payment_logs 스키마 + KYC 대기 |
| `research/PAYMENT_SYSTEM_PLAN.md` | research (신규 박제 정본) | 갭 10건 + P0~P3 + 새 모델 3 + API 9 + sensor 6 |
| `grimoire-server/docs/ai-cost-table.md` | server (정본, cost-accountant 단독 관리) | 18 기능별 마진 표 |
| `grimoire-server/SECURITY.md` §3 | server | 결제 원자성 ($transaction) 절대 규칙 |
| `grimoire-server/ADR.md` | server | 결제 아키텍처 결정 |
| `SYNC_STATUS.md` | 워크스페이스 루트 (정본) | 결제 (Polar) ✅ KYC 대기 |
| `.claude/shared-contracts.md` §7 | .claude (정본) | ANALYSIS_CREDIT_COST = 4 박제 |
| `memory/reference_polar_setup.md` | 메모리 | Polar 3환경 webhook + test mode 제약 |
| `memory/reference_payment_comparison.md` | 메모리 | PayApp/Polar/Lemon Squeezy/Stripe 비교 |

### 2-2. 정본 ↔ 참조 정합성 (cross-ref)

| 출발 → 도착 | 정합 |
|---|---|
| PLANNING §0 → ai-cost-table.md (정본) | ✅ "정본: grimoire-server/docs/ai-cost-table.md" 박제 |
| PLANNING §8 → SECURITY.md §3 | ✅ "결제 원자성 §3 참조" 박제 |
| PAYMENT_SYSTEM_PLAN → CERTI_PROJ 인용 | ✅ §11에 11건 file:line 박제 |
| PAYMENT_SYSTEM_PLAN → Grimoire 코드 | ✅ §12에 10건 file:line 박제 |
| **DOC_MAP.html → PAYMENT_SYSTEM_PLAN** | **❌ 갭 — 신규 정본 미박제** |
| **DOC_MAP.html → reports/PAYMENT_READINESS_AUDIT** | **❌ 갭 — 본 보고서 신규** |

**갭 #1**: `DOC_MAP.html` (J3 정본)에 PAYMENT_SYSTEM_PLAN.md + 본 AUDIT 보고서 박제 누락. J3 정본 갱신은 사용자 결정 영역 — 다음 J7/J3 갱신 시 일괄 반영 권고.

### 2-3. shared-contracts.md 결제 인터페이스 박제 현황

현재 박제됨:
- §6 AskOptions (claude API)
- §7 ANALYSIS_CREDIT_COST (분석 차감 크레딧)

PAY P0 진행 시 신설 필요:
- §11 WebhookEventId 멱등성 인터페이스 (PAY-P0-1)
- §12 PaymentReconciliation 인터페이스 (PAY-P0-2)
- §13 RefundPaymentAtomically 시그니처 (PAY-P1-1)

**갭 #2**: 사전 조건. PAY P0 server 작업 시작 직전에 §11~ 신설 필수 (planner Initializer 책임).

---

## 3. 에이전트 7개 결제 장애 책임 정의 점검

| 에이전트 | 결제 책임 명시 | 책임 범위 |
|---|---|---|
| **grimoire-cost-accountant** | ✅ 명시됨 | 마진 ≥3배 검증 + ai-cost-table 단독 관리 + 외부 API 비용 사전 위임 (이메일/SMS) |
| **grimoire-planner** | ✅ 명시됨 | Sprint 계약 + cost-accountant/researcher/VCK 결과 취합 + 결제 변경 기획 Draft |
| **grimoire-researcher** | ✅ 명시됨 | 경쟁사 (네이버시리즈/카카오페이지/문피아/Wattpad/AO3/한줄) 결제 정책 + Polar/Stripe/PayApp 비교 |
| **grimoire-server** | ✅ 명시됨 | 결제 백엔드 (payment.usecase / polar.adapter / completePaymentAtomically 등) + 마이그레이션 |
| **grimoire-web** | **❌ 갭** | 결제 UI 책임 명시 부재 (`/dashboard/credits` 페이지 / 운영자 수동 지급 UI 등) |
| **grimoire-qa** | **❌ 갭** | 결제 회귀 채점 책임 명시 부재 (결제 sensor 5종 raw stdout 박제 등) |
| **grimoire-visual-canon-keeper** | ✅ 면제 (시각 정본 외) | 결제 UI는 작가 공간 g-* 외부 (admin neutral-*) 영역 |

**갭 #3**: web / qa 에이전트 .md에 결제 관련 책임 1~2줄 추가 권고 (PAY-P0-3 운영자 수동 지급 UI 작업 시 web 위임 정합성 ↑).

---

## 4. 하네스 구성 점검

### 4-1. Skills (25건 중 결제 관련 1건 + 후보 4건)

- ✅ **`refund-logic-audit`** (전용 skill) — UI 문구와 서버 환불 로직 정합성 grep 감사. `disable-model-invocation: true` (사용자 `/refund-logic-audit` 명시 호출만)
  - 사용자 시그널: 2026-04-19 #4에서 Claude가 "자동 환불됩니다" UI 문구 추가했지만 서버 환불 분기 미호출 사례 박제됨
  - 4종 패턴: "자동 환불" / "환불됩니다" / "크레딧 반환" / "크레딧이 반환"
- ✅ `verification-before-completion` — PAY 작업 시 실측 강제
- ✅ `production-bug-triage` — PAY 운영 버그 시 발동
- ✅ `socratic-self-critique` — 결제 결정 Ambiguity ≤0.2 자가 검증
- ✅ `requesting-code-review` — PAY 코드 리뷰 12 항목

### 4-2. Eval Tasks (51건 중 결제 관련 5건)

- ✅ `01-analysis-cancel-refund.json` — 분석 취소 시 환불 회귀 차단
- ✅ `02-cost-margin-pass.json` — §0 원가 마진 회귀 차단
- ✅ `03-payment-credit-atomicity.json` — $transaction 원자성 회귀 차단
- ✅ `04-secret-leak-zero.json` — 시크릿 평문 0건 회귀 차단
- ✅ `26-cost-zero-margin-resilience.json` — 마진 회복탄력성

PAY P0 진행 시 신설 권고 (PAYMENT_SYSTEM_PLAN.md §6 박제):
- ⏳ `regression-52-webhook-event-id-idempotency.json`
- ⏳ `regression-53-payment-reconciliation.json`
- ⏳ `regression-54-admin-grant-credits-ui.json`
- ⏳ `regression-55-refund-atomicity.json`
- ⏳ `regression-56-payment-email-notification.json`
- ⏳ `regression-57-payment-retry-reuse.json`

### 4-3. Knowledge (8건)

- ✅ `red-team-constitution.md` — P4 (원가) + P16 (결제 원자성) + P13/P14/P15 (보안) 박제
- ✅ `book-harness-engineering-completion.md` — 책 Ch 18 비용 관리 패턴
- ✅ `agent-system.md` + `agent-interaction-matrix.md` — 7×7 핸드오프 (cost-accountant + planner + server 결제 흐름 박제)
- ✅ `sensors.md` — 25 sensor 명세 (credit-atomicity / cost-margin / adversarial 등)

### 4-4. Hooks (9 이벤트 14 스크립트)

- ✅ `PostToolUseFailure` (Chrome MCP F2) — 결제 폴링 / 영수증 PDF 다운로드 시 활용
- ✅ `pre-commit` (claude-docs) — eval-precommit + adversarial 자동 차단
- ✅ `pre-push` (server + web) — 결제 변경 시 jest + tsc + build + docs sync 자동 검증

### 4-5. Sensors (25건 중 결제 관련 5건)

- ✅ `sensor-credit-atomicity.sh` — $transaction 패턴 강제 (1건 false positive — 정밀화 권고)
- ✅ `sensor-cost-margin.sh` — 18 마진 항목 자동 채점
- ✅ `sensor-secret-leak.sh` — Polar webhook secret 하드코딩 차단
- ✅ `sensor-adversarial-pre-commit.sh` — 19 Principles (P3/P4/P5/P13/P14/P15/P16/P17/P18/P19 결제 영역)
- ✅ `sensor-shared-contracts.sh` — AskOptions / ANALYSIS_CREDIT_COST drift 차단

PAY P0 진행 시 신설 권고:
- ⏳ `sensor-payment-idempotency.sh` (PAY-P0-1)
- ⏳ `sensor-payment-reconciliation.sh` (PAY-P0-2)
- ⏳ `sensor-refund-atomicity.sh` (PAY-P1-1)
- ⏳ `sensor-payment-notification.sh` (PAY-P1-2)
- ⏳ `sensor-admin-audit-coverage.sh` (PAY-P2-3)

---

## 5. 갭 종합 + 보강 권고

| # | 영역 | 갭 | 우선순위 | 자율 가능? |
|---|---|---|---|---|
| 1 | sensor | sensor-credit-atomicity false positive (creditLog.create 검출 실패) | P2 | ⚠️ 로직 변경 — 사용자 명시 |
| 2 | 문서 | DOC_MAP.html에 PAYMENT_SYSTEM_PLAN + 본 AUDIT 미박제 | P3 | ⚠️ J3 정본 — 사용자 명시 |
| 3 | shared-contracts | PAY P0 진행 시 §11+ 신설 (사전 조건) | P0 (PAY 시작 시) | ✅ planner Initializer 책임 |
| 4 | 에이전트 | grimoire-web .md 결제 책임 명시 부재 | P1 | ⚠️ 정본 — 사용자 명시 |
| 5 | 에이전트 | grimoire-qa .md 결제 책임 명시 부재 | P1 | ⚠️ 정본 — 사용자 명시 |

**즉시 차단 사유 0건** — 5건 모두 점검 결과로만 식별. PAY P0 자체 진행은 사용자 명시 후 즉시 가능.

---

## 6. CERTI_PROJ 학습 박제 회수성

| 인사이트 박제 위치 | 회수 가능 |
|---|---|
| `research/PAYMENT_SYSTEM_PLAN.md` §2 (Top 12 패턴 + 안티패턴 8) | ✅ |
| `research/PAYMENT_SYSTEM_PLAN.md` §11 (CERTI_PROJ 11 file:line 인용) | ✅ |
| `memory/project_session_20260503_2.md §PAY` | ✅ |
| `memory/project_remaining_tasks.md` PAY-P0~P3 | ✅ |

PAY 작업 시작 시 위 4 위치만 Read하면 즉시 자율 진행 가능 상태.

---

## 7. 최종 판정

**상태: ✅ READY**

PAY-P0 (3건, ~7h) / PAY-P1 (4건, ~7h + 작업 A 결합) 사용자 명시 후 즉시 자율 진행 가능합니다. 위 5 갭 중 #3은 PAY 작업 시작 시 planner가 자율 보강, 나머지 4건은 별도 보강 트랙으로 사용자 명시 시 처리.

---

## 8. 다음 액션 (사용자 결정 영역)

1. PAY-P0 즉시 진행 vs 작업 D/E 후 진행 (PAYMENT_SYSTEM_PLAN.md §8 옵션 A/B/C 선택)
2. 갭 #1 (sensor false positive) 정밀화 트랙 추가 여부
3. 갭 #2 (DOC_MAP 정합) J3 갱신 트리거 시점
4. 갭 #4/#5 (web/qa 에이전트 결제 책임 명시) 1~2줄 추가 승인 여부

---

## 변경 이력
- 2026-05-03 #10_7: 본 AUDIT 보고서 신설 — 6 영역 점검 + 갭 5건 식별 + 즉시 차단 사유 0건 판정
