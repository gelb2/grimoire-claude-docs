# Shared Contracts — ProjectGrimoire 7 Agents 인터페이스 규약

> 책 "하네스 엔지니어링 완전 정복" Ch 16 멀티 에이전트 의사결정 전파 패턴 적용.
> agent-interaction-matrix.md(7×7 핸드오프 메타)의 보완 정본.
> 본 파일은 **공유 상태 파일** — 인터페이스 변경 시 즉시 갱신 (책 Ch 16 충돌 2번 해결책).

> 도입: 2026-04-27 #9 (Phase 2)
> 절대 규칙: 어떤 agent든 본 파일에 명시된 인터페이스를 변경하면 **즉시 본 파일 갱신** + git commit. 미갱신 시 다음 agent가 통합 단계에서 깨짐.

## 사용 규칙 (모든 agent 공통)

1. **변경 시 즉시 갱신**: agent A가 인터페이스 변경 → A가 본 파일 갱신 → 다음 agent는 갱신된 contracts 참조
2. **변경 이력 누적**: 각 섹션 하단에 `### 변경 이력` 박제 (date — agent — 변경 요약)
3. **삭제 금지**: 폐기된 인터페이스는 `[DEPRECATED]` 표기만, 본문 보존 (역사)
4. **agents/.md 본문에 참조 박제**: 각 agent 정의에 "Shared Contracts 참조 — `.claude/shared-contracts.md`" 1줄 추가

---

## 0. reports/SWEEP_REPORT.md (researcher → planner / cost-accountant)

**생산자**: grimoire-researcher
**소비자**: grimoire-planner (시장 컨텍스트), grimoire-cost-accountant (AI 가격 변동 감지)
**참조**: agent-interaction-matrix.md §3

### 필수 섹션

```markdown
# SWEEP_REPORT — YYYY-MM-DD

## 0. 메타
- 작업일: YYYY-MM-DD
- 스윕 범위: 경쟁사 (네이버 시리즈 / 카카오페이지 / 문피아 / Wattpad / AO3 / 한줄) + AI 모델 가격 (Anthropic / OpenAI / Google) + 환율
- 변동 감지: ✅ 있음 / ❌ 없음

## 1. 경쟁사 변동
- {플랫폼명}: 변동 사항 (가격, 정책, 신기능)

## 2. AI 모델 가격 (researcher 매일 갱신)
- Claude Sonnet 4.6 — input/output 가격
- Claude Haiku 4.5 — 가격
- GPT-5 — 가격
- 환율 KRW/USD

## 3. 가격 변동 감지 시 트리거
- 변동 ≥5% → reports/COST_ALERT.md 생성 → cost-accountant 즉시 호출

## 4. HANDOFF
- planner: 시장 컨텍스트 (PLANNER_REPORT 작성 시 참조)
- cost-accountant: 가격 변동 영향 받는 기능 재계산
```

### 변경 이력
- 2026-05-02 묶음 N NEW-14: shared-contracts에 추가 박제 (이전엔 reports/ 6개 중 SWEEP만 미명시)

---

## 1. reports/PLANNER_REPORT.md (planner → server/web)

**생산자**: grimoire-planner
**소비자**: grimoire-server / grimoire-web
**참조**: agent-interaction-matrix.md §3

### 필수 섹션

```markdown
# PLANNER_REPORT — YYYY-MM-DD

## 0. 메타
- 작업일: YYYY-MM-DD
- 참조 sweep: reports/SWEEP_REPORT.md (researcher 산출물)
- 참조 cost-audit: reports/COST_AUDIT_REPORT.md
- 참조 visual-canon: reports/VISUAL_CANON_REPORT.md (있을 시)

## 1. 오늘 위임
### server 섹션
- {기능명}
  - 위치: {파일 경로}
  - 검증 게이트: {sensor 명 + 기대 결과}
  - 사전 승인: cost-accountant ✅ / VCK ✅ (해당 시)

### web 섹션
- {기능명}
  - 위치: {파일 경로}
  - 검증 게이트: {sensor 명 + Playwright 등}
  - 사전 승인: VCK ✅ (해당 시)

## 2. HANDOFF
- next agent: server / web (병렬)
- 마감: 다음 세션 (또는 특정 일자)
```

### 변경 이력
- 2026-04-26: agent-interaction-matrix.md §3 정합 박제

---

## 2. reports/COST_AUDIT_REPORT.md (cost-accountant → planner/server/web/qa)

**생산자**: grimoire-cost-accountant
**소비자**: grimoire-planner (승인/거절), grimoire-server/web (참조), grimoire-qa (배포 게이트)

### 필수 섹션

```markdown
# COST_AUDIT_REPORT — YYYY-MM-DD

## 0. 종합 판정
- 신규 AI 기능: ✅ 승인 / ❌ 거절
- 기존 마진: PASS / WARN / FAIL
- §0 위반 항목: N건

## 1. 안전배수 표
| 패키지 | 판매가 | AI 원가 | 수수료 | 총 원가 | 안전배수 | 판정 |
| ... | ... | ... | ... | ... | ... | PASS/WARN/FAIL |

## 2. 시뮬 (위험 변동 검증)
- Sonnet input/output +20% → 영향 표
- 환율 +N% → 영향 표
- 결제 수수료 변동 → 영향 표

## 3. HANDOFF
- planner: {승인/거절 + 사유}
- server: {코드 적용 시 ANALYSIS_CREDIT_COST 등 상수 변경 안내}
- qa: {배포 게이트 — CRITICAL 0건이어야 통과}
```

### 변경 이력
- 2026-04-26 #9: WARN 5건 정밀 분석 + 시뮬 (cost-accountant 1번째 위임)
- 2026-04-27 #9: 분석 4 크레딧 인상 시뮬 (cost-accountant 2번째 위임)
- 2026-04-27 #9: LLM-as-Judge 운영 비용 가드 (cost-accountant 7번째 위임)

---

## 3. reports/VISUAL_CANON_REPORT.md (visual-canon-keeper → web/qa)

**생산자**: grimoire-visual-canon-keeper
**소비자**: grimoire-web (수정 요청), grimoire-qa (배포 게이트)

### 필수 섹션

```markdown
# VISUAL_CANON_REPORT — YYYY-MM-DD

## 0. 종합 판정
- CRITICAL: N건 (즉시 코드 수정 필수)
- WARN: N건 (문서 또는 코드 수정 권장)
- 신규 컴포넌트 검수: ✅ PASS / ⚠️ CONDITIONAL / ❌ FAIL

## 1. 사슴악마 정본 대조 결과
- 작가공간: 히어로 / antler 디바이더 / 시리즈 탭 / 에피소드 카드 / PREFACE — 항목별 PASS/FAIL
- 에피소드 뷰어: 타이핑 애니메이션 / 소제목 / 본문 / 구분선 / 이탤릭 / 이전·다음 화 — 항목별

## 2. 새 시각 컴포넌트 검수
- {컴포넌트명}: 정본 패턴 부합도 (1~5)

## 3. HANDOFF
- web: {수정 필요 항목 + 파일 경로}
- qa: {배포 게이트 — CRITICAL 0건이어야 통과}
```

### 변경 이력
- 2026-04-26: agent-interaction-matrix.md §3 정합 박제

---

## 4. reports/DEV_REPORT.md (server + web → qa)

**생산자**: grimoire-server, grimoire-web (각 섹션 분리)
**소비자**: grimoire-qa

### 필수 섹션

```markdown
# DEV_REPORT — YYYY-MM-DD

## Server 섹션
### 1. 메타데이터
- 참조 PLANNER_REPORT / COST_AUDIT / VCK 요약

### 2. 사전 게이트 통과 증거
- cost-accountant: ✅ 승인 ID + 마진 (해당 시)
- VCK: ✅ 검수 ID (해당 시)

### 3. 구현 결과
- 엔드포인트/usecase/마이그레이션 단위

### 4. 수정 파일 목록

### 5. 센서 결과 — raw stdout 전체 (요약 금지)
- sensor-server.sh
- sensor-docs-sync.sh
- (해당 시) sensor-credit-atomicity.sh / sensor-secret-leak.sh

### 6. Git 커밋 증거 (server 레포)

### 7. HANDOFF
- web: 동기화 필요 docs/
- qa: sensor 독립 재실행 대상

## Web 섹션
### 1~7. (구조 동일, sensor-web.sh + Playwright 결과 추가)
```

### 변경 이력
- 2026-04-26: agent-interaction-matrix.md §3 정합 박제

---

## 5. reports/QA_REPORT.md (qa → 사용자)

**생산자**: grimoire-qa
**소비자**: 사용자 (배포 게이트 판정)

### 필수 섹션

```markdown
# QA_REPORT — YYYY-MM-DD

## 0. 배포 게이트 판정
- ✅ PASS — 배포 가능
- ❌ FAIL — 배포 차단 (사유 + 회귀 항목)

## 1. dev/qa 센서 대조
- sensor-server: dev PASS / qa PASS → ✅
- sensor-web: dev PASS / qa PASS → ✅
- sensor-docs-sync: dev PASS / qa PASS → ✅
- (해당 시) sensor-credit-atomicity / sensor-secret-leak / sensor-cost-margin

## 2. CRITICAL 영역
- COST_AUDIT CRITICAL: N건 (마진 <3배 기능)
- VISUAL_CANON CRITICAL: N건 (사슴악마 정본 위반)
- 보안: secret-leak FAIL N건

## 3. Eval 결과 (2026-04-27 P0 도입 후)
- 회귀 모드: PASS N/M = X% (baseline 대비 회귀 X%p)
- EDD 모드 (해당 시): PASS N/M = X%

## 4. 회귀 항목 (배포 차단 사유)

## 5. HANDOFF to 사용자
- 배포 명령: make deploy-prod (server + web)
- 추가 검증: dev에서 X 화면 직접 확인
```

### 변경 이력
- 2026-04-26: agent-interaction-matrix.md §3 정합 박제
- 2026-04-27 #9: §3 Eval 결과 섹션 추가 (P0 도입)

---

## 6. AskOptions (server 도메인 — claude API 인터페이스)

**위치**: `grimoire-server/src/domain/port/outbound/claude-api.port.ts`
**적용**: 모든 askClaude 호출 (분석/테마/채팅)

### 시그니처
```typescript
export interface AskOptions {
  maxTokens?: number;
  signal?: AbortSignal;  // 2026-04-27 #9 N (SDK signal 전파) 신설
}

export interface ClaudeApiPort {
  generateTheme(description: string): Promise<AuthorTheme>;
  ask(systemPrompt: string, userMessage: string, options?: AskOptions): Promise<string>;
}
```

### 변경 이력
- 2026-04-27 #9 N: signal 필드 추가 (SDK abort 시 fetch 즉시 cancel)

---

## 7. ANALYSIS_CREDIT_COST (server 도메인 — 분석 차감 크레딧)

**위치**: `grimoire-server/src/domain/model/config.ts`
**적용**: novel-analysis.usecase.ts (차감/환불 분기)

### 현재 값
```typescript
export const ANALYSIS_CREDIT_COST = 4;  // 2026-04-27 인상 (3 → 4)
```

### 변경 시 동시 갱신 대상
- `grimoire-server/docs/ai-cost-table.md` §3-2 (cost-accountant 단독 관리)
- `grimoire-server/docs/ai-analysis-spec.md` §5-1 + §8
- `grimoire-web/docs/ai-analysis-spec.md` (server 정본 복사)
- `grimoire-web/src/app/dashboard/analysis/page.tsx` (안내 문구)
- `grimoire-web/src/app/dashboard/credits/page.tsx` (가격 안내)
- `grimoire-server/src/application/analysis/novel-analysis.usecase.spec.ts` (차감/환불 spec)

### 변경 이력
- 2026-04-19 F2: 3 크레딧 확정
- 2026-04-27 #9: 3 → 4 인상 (cost-accountant 시뮬 검증, 분석/베스트 FAIL 약점 해소)

---

## 8. Eval task 형식 (eval 시스템 — 2026-04-27 P0 신설)

**위치**: `eval/tasks/*.json`
**적용**: 모든 회귀/EDD 태스크

### 시그니처
```json
{
  "id": "regression-XXX | edd-XXX",
  "name": "한국어 태스크 명",
  "category": "security|cost_zero|visual_canon|author_content|type_safety|convention|api_contract|edge_case|test_coverage",
  "source_session": "YYYYMMDD_N (실패 박제 출처)",
  "prompt": "검증 의도 한 문장",
  "eval_criteria": [
    {"type": "grep|grep_count|command|inventory_match|llm", ...}
  ],
  "threshold": 1.0,         // regression: 1.0 / EDD: 카테고리별 0.65~0.95
  "edd_threshold": 0.7,     // optional, EDD 모드용 별도 임계
  "runs": 1                 // regression: 1 / EDD: 5~10
}
```

### category별 EDD threshold (cost-accountant 권장)
- security: 0.95+
- cost_zero: 0.95+
- visual_canon: 0.90+
- author_content: 1.00 (무관용)
- type_safety: 0.90+
- convention: 0.85
- api_contract: 0.85
- edge_case: 0.75
- test_coverage: 0.65

### 변경 이력
- 2026-04-27 #9 P0: 회귀 모드 도입 (20 tasks, 100% baseline)
- 2026-04-27 #9 P1: EDD 모드 인프라 + LLM-as-Judge 가드

---

## 9. LLM-as-Judge 비용 가드 (eval 시스템)

**위치**: `eval/scripts/grade-llm.py`
**적용**: --llm-judge 옵션 사용 시

### 가드 (cost-accountant 위임 결과 박제)
- 일일 알림 임계: ₩2,000
- 월간 한도: ₩50,000
- 호출당 단가: ₩20 (Sonnet 4.6, 2K input + 0.5K output)
- LLM 태스크 비율 ≤35% (20 tasks 중 7개 이하)
- 일일 EDD 실행 ≤2회

### 비용 적재
- 위치: `.claude/state/llm-judge-cost.jsonl`
- 형식: `{ts, task_id, criterion_idx, cost_krw}`
- 월간/일간 집계는 grade-llm.py 자체에서 수행

### 변경 이력
- 2026-04-27 #9: cost-accountant 7번째 위임 결과 박제

---

## 10. PostToolUseFailure hook 정책 (Chrome MCP F2)

**위치**: `.claude/scripts/posttooluse-failure-handler.sh`
**적용**: settings.json hooks PostToolUseFailure

### 정책 시그니처
- reCAPTCHA 의심 키워드 → block + 사용자 직접 통과 안내
- prod 도메인 (grimoire-book.com) → block + 사용자 직접 검증
- dev/일반 → 1회 재시도 신호 (additionalContext)
- 사용자 interrupt → skip
- 비-Chrome 도구 → 적재만

### 변경 이력
- 2026-04-27 #9 F2: 신설 (Chrome MCP 안전 정책 자동화)

---

## 11. WebhookEventIdempotency (server 도메인 — Polar webhook 멱등성)

**위치**: `grimoire-server/src/domain/port/outbound/webhook-event-repository.port.ts`
**적용**: `payment.usecase.processWebhook` (PAY-P0-1, 2026-05-03 신설)

### 목적
Polar(또는 다른 PG)가 같은 webhook event를 retry 전송 시 **DB unique 제약**으로 중복 처리 원천 차단. 같은 payment의 다른 event 종류(succeeded → refunded) 모두 개별 eventId로 식별 가능.

### 시그니처
```typescript
export interface WebhookEventRecord {
  id: string
  eventId: string                                                  // Polar webhook-id 헤더
  source: string                                                   // 'polar'
  eventType: string                                                // 'order.paid' / 'order.refunded' / ...
  status: 'processed' | 'skipped' | 'failed'
  processedAt: Date
}

export interface WebhookEventRepositoryPort {
  findByEventId(eventId: string): Promise<WebhookEventRecord | null>
  /** event 박제 — eventId unique 위반(P2002) 시 null 반환 (race 안전) */
  createIfAbsent(input: {
    eventId: string
    source: string
    eventType: string
    payload: object
    status?: 'processed' | 'skipped' | 'failed'
    errorMessage?: string | null
  }): Promise<WebhookEventRecord | null>
  markStatus(eventId: string, status: 'processed' | 'skipped' | 'failed', errorMessage?: string): Promise<void>
}
```

### NormalizedWebhookEvent 시그니처 변경 (§6 AskOptions 형식 정합)
```typescript
export interface NormalizedWebhookEvent {
  eventId: string                                                  // [신설 PAY-P0-1] Polar webhook-id 헤더
  type: string
  tradeNo: string
  amount: number
  status: 'success' | 'fail' | 'cancel'
  userId?: string
}
```

### DB 모델 (Prisma)
```prisma
model WebhookEvent {
  id           String   @id @default(uuid())
  eventId      String   @unique @map("event_id")
  source       String                            // 'polar'
  eventType    String   @map("event_type")
  payload      Json
  processedAt  DateTime @default(now()) @map("processed_at") @db.Timestamptz(3)
  status       String   @default("processed")    // 'processed' | 'skipped' | 'failed'
  errorMessage String?  @map("error_message")

  @@index([eventType, processedAt])
  @@map("webhook_events")
}
```

### 처리 흐름 (payment.usecase.processWebhook)
1. polar.adapter.verifyAndParseWebhook 호출 → eventId 박제된 NormalizedWebhookEvent 반환
2. webhookEventRepo.findByEventId(event.eventId) → 이미 있으면 즉시 `{ processed: false, reason: 'duplicate_event' }` 반환 (200 OK)
3. payment 처리 (현재 로직 그대로)
4. 성공 시 webhookEventRepo.createIfAbsent(eventId, ..., status='processed') — race 시 null 반환 시 다른 worker 처리 중으로 간주, 무시
5. 실패 시 createIfAbsent(..., status='failed', errorMessage=...) — DLQ 보강 전 임시 박제

### 변경 시 동시 갱신 대상
- `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` (webhook-id 헤더 추출)
- `grimoire-server/src/application/payment/payment.usecase.ts` (findByEventId 게이트)
- `grimoire-server/src/application/payment/payment.usecase.spec.ts` (멱등성 spec)
- `grimoire-server/prisma/schema.prisma` (WebhookEvent 모델)
- `grimoire-server/prisma/migrations/{ts}_webhook_event_idempotency/`
- `grimoire-server/docs/data-model.md` + `SCHEMA.md` (정본 갱신)
- `eval/tasks/regression-52-webhook-event-id-idempotency.json` (회귀 차단)
- `.claude/scripts/sensor-payment-idempotency.sh` (패턴 검증)

### 변경 이력
- 2026-05-03 #10_7 PAY-P0-1: 신설 — webhook event_id 멱등성 테이블 (CERTI_PROJ inapi 분석 + research/PAYMENT_SYSTEM_PLAN.md §3-1 정합)

---

## 12. PaymentReconciliation (server 도메인 — PG↔DB 정합성 검증 cron)

**위치**:
- Job: `grimoire-server/src/application/payment/payment-reconciliation.job.ts`
- Port (gateway): `grimoire-server/src/domain/port/outbound/payment-gateway.port.ts` (listRecentCheckouts)
- Port (checkpoint): `grimoire-server/src/domain/port/outbound/reconciliation-checkpoint-repository.port.ts`
- DB 모델: `grimoire-server/prisma/schema.prisma` (ReconciliationCheckpoint singleton)

**적용**: NestJS @Cron('0 */10 * * * *') 10분 주기. webhook 누락 자동 발견 + 자동 보정. cost-accountant PAY-P0-2 (2026-05-03) 보고에서 Polar `/v1` rate limit 분당 500회 default 그룹 → 사용률 1% 미만 압도적 PASS, 10분 권고 유지.

### 시그니처

```typescript
// PaymentGatewayPort 확장
export interface NormalizedCheckout {
  externalTransactionId: string  // Polar checkout.id
  status: 'succeeded' | 'refunded' | 'failed' | 'open'
  amount: number                  // KRW
  metadata?: Record<string, unknown>
  createdAt: Date
}

export interface PaymentGatewayPort {
  // 기존 +
  listRecentCheckouts(since: Date, limit: number): Promise<NormalizedCheckout[]>
}

// 신규 Port
export interface ReconciliationCheckpointRecord {
  id: string                    // 항상 'singleton'
  lastRunAt: Date
  processedCount: number
  boostCount: number
  mismatchCount: number
  expireCount: number
  errorMessage: string | null
  updatedAt: Date
}

export interface ReconciliationCheckpointRepositoryPort {
  /** singleton row 조회 — 미존재 시 default seed 반환 (lastRunAt = 24h 전) */
  findSingleton(): Promise<ReconciliationCheckpointRecord>
  /** singleton row 갱신 (upsert) */
  update(data: {
    lastRunAt: Date
    processedCount: number
    boostCount: number
    mismatchCount: number
    expireCount: number
    errorMessage?: string | null
  }): Promise<ReconciliationCheckpointRecord>
}

// PaymentRepositoryPort 확장
export interface PaymentRepositoryPort {
  // 기존 +
  findPendingPaymentsOlderThan(hours: number): Promise<PaymentRecord[]>
  expirePayment(paymentId: string): Promise<void>
}
```

### DB 모델 (Prisma)
```prisma
model ReconciliationCheckpoint {
  id              String   @id @default("singleton")  // 항상 1 row
  lastRunAt       DateTime @map("last_run_at") @db.Timestamptz(3)
  processedCount  Int      @default(0) @map("processed_count")
  boostCount      Int      @default(0) @map("boost_count")
  mismatchCount   Int      @default(0) @map("mismatch_count")
  expireCount     Int      @default(0) @map("expire_count")
  errorMessage    String?  @map("error_message")
  updatedAt       DateTime @updatedAt @map("updated_at") @db.Timestamptz(3)

  @@map("reconciliation_checkpoints")
}
```

### 정책
- ReconciliationCheckpoint는 항상 1 row 유지 (id='singleton'). 마이그레이션에서 INSERT seed 1회.
- cron 동시 실행 차단: in-memory `isRunning` lock + try-finally (replicas=1 가정, ≥2는 PAY-P1 advisory_lock으로 강화)
- **4 시나리오**:
  - **S1 boost** (PG=succeeded + DB=pending) → `completePaymentAtomically` 호출 + AuditLog operator='system_reconciliation' / action='reconciliation_boost'
  - **S2 mismatch** (PG=refunded + DB=completed) → logger.warn + AuditLog action='reconciliation_refund_mismatch' (P1-1 refundPaymentAtomically 미도입 — 운영자 수동 처리)
  - **S3 expire** (PG=NotFound + DB=pending + 24h 경과) → `expirePayment` 호출 + AuditLog action='reconciliation_expire'
  - **S4 정합** → skip (no-op)
- 모든 자동 보정 action은 AdminAuditLog operator='system_reconciliation' + 3 action 식별자 박제

### 처리 흐름 (PaymentReconciliationJob.run)
1. `if (this.isRunning) return` — 동시 실행 차단
2. `this.isRunning = true; try { ... } finally { this.isRunning = false }`
3. `checkpoint = await checkpointRepo.findSingleton()`
4. `polarCheckouts = await paymentGateway.listRecentCheckouts(checkpoint.lastRunAt, 100)` — 페이지네이션
5. polarCheckouts 각각:
   - `payment = await paymentRepo.findByExternalTransactionId(checkout.externalTransactionId)`
   - 4 시나리오 분기 (S1/S2/S3/S4)
6. `pendingPayments = await paymentRepo.findPendingPaymentsOlderThan(24)` — 24h 만료 대상
7. pendingPayments 각각: PG에 record 없으면 expire (S3)
8. `checkpointRepo.update({ lastRunAt: now, processedCount, boostCount, mismatchCount, expireCount })`

### 변경 시 동시 갱신 대상
- `grimoire-server/src/application/payment/payment-reconciliation.job.ts` (신설)
- `grimoire-server/src/application/payment/payment-reconciliation.job.spec.ts` (신설)
- `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` (listRecentCheckouts 구현)
- `grimoire-server/src/adapter/outbound/persistence/prisma-reconciliation-checkpoint.repository.ts` (신설)
- `grimoire-server/src/app.module.ts` (ScheduleModule.forRoot + PaymentReconciliationJob provider + DI)
- `grimoire-server/package.json` (@nestjs/schedule 의존성)
- `grimoire-server/prisma/schema.prisma` + `prisma/migrations/{ts}_add_reconciliation_checkpoint/`
- `grimoire-server/docs/data-model.md` + `SCHEMA.md` (server 정본)
- `eval/tasks/regression-53-payment-reconciliation.json`
- `.claude/scripts/sensor-payment-reconciliation.sh`

### 변경 이력
- 2026-05-03 #10_7 PAY-P0-2: 신설 — PG↔DB 정합성 검증 cron (의료 결제 시스템 정합성 검증 패턴 차용 + Grimoire 10분 주기 완화). cost-accountant Polar `/v1` rate limit 사용률 1% PASS, §0 면제.

---

## 13. RefundPaymentAtomically (server 도메인 — 환불 시 크레딧 환수 트랜잭션)

**위치**:
- UseCase: `grimoire-server/src/application/payment/refund-payment.usecase.ts`
- Port: `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (refundPaymentAtomically 시그니처)
- DB 모델: `grimoire-server/prisma/schema.prisma` (RefundLog)

**적용**: Polar `order.refunded` webhook 수신 시 `payment.usecase.processWebhook` event.status='cancel' 분기에서 호출. 환불 시 사용자 크레딧 환수 + RefundLog 박제 + AdminAuditLog(operator='system_refund').

### 시그니처

```typescript
// PaymentRepositoryPort 확장
export interface PaymentRepositoryPort {
  // 기존 +
  refundPaymentAtomically(input: {
    paymentId: string
    authorId: string
    credits: number          // 환수할 크레딧
    refundedAmount: number   // PG 환불 금액 (KRW)
    reason: string
    source: 'webhook' | 'manual'
  }): Promise<{
    actualDeducted: number   // 실제 차감 (잔액 부족 시 잔액만큼)
    deficitCredits: number   // 부족분 (잔액 < credits 시 양수, 정상 시 0)
  }>
}

// RefundLog DB 모델 (Prisma)
model RefundLog {
  id              String   @id @default(uuid())
  paymentId       String   @map("payment_id")
  amount          Int                                  // PG 환불 금액 (KRW)
  credits         Int                                  // 요청 환수 크레딧
  deficitCredits  Int      @default(0) @map("deficit_credits")  // 잔액 부족분 (운영자 회수 대상)
  reason          String
  processedAt     DateTime @default(now()) @map("processed_at") @db.Timestamptz(3)
  source          String                               // 'webhook' | 'manual'

  @@index([paymentId])
  @@map("refund_logs")
}
```

### 정책 — 3중 멱등성 + 잔액 부족 처리

**3중 멱등성 (환불 webhook 중복 차단)**:
- L1: PAY-P0-1 `webhook_events.eventId @unique` (기존)
- L2: payment.status='refunded' 체크 (이미 환불된 payment는 skip)
- L3: RefundLog 박제 (운영자 조회 + 추적용)

**잔액 부족 분기**:
- Author.credits ≥ credits → 정상 환수 (`actualDeducted = credits`, `deficitCredits = 0`)
- Author.credits < credits → 0 fix + `actualDeducted = Author.credits`, `deficitCredits = credits - Author.credits`
- 음수 잔액 절대 차단 (Author.credits = 0 floor)

**$transaction 본문**:
```typescript
await this.prisma.$transaction(async (tx) => {
  // 1. Payment 상태 갱신
  await tx.payment.update({ where: { id: paymentId }, data: { status: 'refunded' } })
  // 2. Author.credits decrement (0 fix)
  const author = await tx.author.findUnique({ where: { id: authorId } })
  const actualDeducted = Math.min(author.credits, credits)
  const deficitCredits = Math.max(0, credits - author.credits)
  await tx.author.update({ where: { id: authorId }, data: { credits: { decrement: actualDeducted } } })
  // 3. CreditLog 음수 amount 박제 (대칭)
  await tx.creditLog.create({ data: { authorId, amount: -actualDeducted, reason: `refund_${paymentId}_${reason}` } })
  // 4. RefundLog 박제
  await tx.refundLog.create({ data: { paymentId, amount: refundedAmount, credits, deficitCredits, reason, source } })
  return { actualDeducted, deficitCredits }
})
// 5. AdminAuditLog 후행 (트랜잭션 외)
await this.auditLogService.log(
  'system_refund',
  deficitCredits > 0 ? 'refund_deficit' : 'refund_normal',
  paymentId,
  { authorId, refundedAmount, creditsRequested: credits, creditsActuallyDeducted: actualDeducted, deficitCredits, reason, source }
)
```

### 변경 시 동시 갱신 대상
- `grimoire-server/src/application/payment/refund-payment.usecase.ts` (신설)
- `grimoire-server/src/application/payment/refund-payment.usecase.spec.ts` (신설)
- `grimoire-server/src/application/payment/payment.usecase.ts` (event.status='cancel' 분기에서 refund usecase 호출)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (refundPaymentAtomically 구현)
- `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (시그니처 추가)
- `grimoire-server/src/app.module.ts` (RefundPaymentUseCase DI)
- `grimoire-server/prisma/schema.prisma` (RefundLog) + `prisma/migrations/{ts}_add_refund_log/`
- `grimoire-server/docs/data-model.md` + `SCHEMA.md` (RefundLog 박제)
- `eval/tasks/regression-55-refund-atomicity.json`
- `.claude/scripts/sensor-refund-atomicity.sh`

### 변경 이력
- 2026-05-04 #10_7 PAY-P1-1: 신설 — Polar 환불 webhook 시 크레딧 환수 트랜잭션 + RefundLog + AdminAuditLog. 적자 위험 차단(현재 webhook 'cancel'은 status='refunded' 마킹만, 크레딧 환수 부재). PAY-P0-2 'system_reconciliation' 패턴 정합 (operator='system_refund').

---

## 14. PaymentRetryReuse (server 도메인 — 결제 실패 retry 정책)

**위치**:
- UseCase 변경: `grimoire-server/src/application/payment/payment.usecase.ts` (`initiatePayment` 진입 게이트, line 43-70)
- Cron Job: `grimoire-server/src/application/payment/payment-cleanup.job.ts` (신설 — `@Cron('0 0 4 * * *')`, line 45)
- Port (extend): `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (`findReusablePendingPayment` 시그니처, line 57-71)
- Adapter: `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (구현, line 85-99)
- DB 모델: `grimoire-server/prisma/schema.prisma` (변경 0건 — 'expired' status는 PAY-P0-2에서 도입됨, 본 sprint에서 활용)

**적용**: 사용자가 결제 실패 후 재시도 시 동일 (authorId, productId, status='pending', createdAt > now-24h) Payment row 재사용 + Polar Checkout URL 재발급. 만료된 pending row는 매일 새벽 4시 cron으로 'expired' 마킹 (delete 아닌 soft expire).

### 시그니처

```typescript
// PaymentRepositoryPort 확장
findReusablePendingPayment(
  authorId: string,
  productId: string,
  expireSince: Date,    // now - 24h
): Promise<PaymentRecord | null>

// PaymentUseCase.initiatePayment 진입 흐름
async initiatePayment(authorId, productId, returnUrl) {
  const expireSince = new Date(Date.now() - 24 * 60 * 60 * 1000)
  let payment = await this.paymentRepo.findReusablePendingPayment(authorId, productId, expireSince)
  if (!payment) {
    payment = await this.paymentRepo.create({ authorId, productId, ... })
  }
  const result = await this.paymentGateway.initiatePayment({ ... })
  await this.paymentRepo.updateExternalTransactionId(payment.id, result.tradeNo)
  return { paymentId: payment.id, paymentUrl: result.paymentUrl, tradeNo: result.tradeNo }
}

// PaymentCleanupJob (신설)
@Cron('0 0 4 * * *')
async cleanupExpiredPendingPayments(): Promise<void>
```

### 정책

- **재사용 조건**: `authorId AND productId AND status='pending' AND createdAt > now - 24h` ORDER BY `createdAt DESC` LIMIT 1
- **재사용 시 Polar URL**: 매 호출마다 신규 발급 (Polar SDK 정책 — 같은 externalTransactionId 재발급 불가)
- **race condition 차단**: 트랜잭션 SELECT FOR UPDATE 권고 (옵션 A — DB schema 변경 0건). Generator 구현은 spec 수준 race 검증 (Promise.all 시뮬). DB advisory_lock은 P2 보류 (replicas ≥2 시점).
- **만료 정책**: 24h 초과 pending row → cron이 'expired' 마킹 (delete 아닌 soft expire — 운영자 추적 가능)
- **AuditLog**: cron 발동 시 operator='system_cleanup' + action='payment_expire' 박제 (PAY-P0-2 'system_reconciliation' 패턴 정합)
- **PAY-P0-2 cron과 분리**: 별도 클래스(`payment-cleanup.job.ts`) + 별도 시간대(새벽 4시 vs PAY-P0-2 새벽 3시)
- **비활성화 게이트**: `process.env.PAYMENT_CLEANUP_DISABLED === '1'` 즉시 return (운영자 수동 차단용)

### 처리 흐름 (PaymentUseCase.initiatePayment)

1. `expireSince = new Date(Date.now() - 24*60*60*1000)`
2. `paymentRepo.findReusablePendingPayment(authorId, productId, expireSince)`
3. 결과 null → `paymentRepo.create({ ... })` 신규 생성
4. 결과 not-null → 재사용 (paymentId 동일)
5. `paymentGateway.initiatePayment({ ... })` Polar SDK 호출 (신규 URL 발급)
6. `paymentRepo.updateExternalTransactionId(payment.id, result.tradeNo)` 갱신
7. return `{ paymentId, paymentUrl, tradeNo }`

### 처리 흐름 (PaymentCleanupJob.cleanupExpiredPendingPayments)

1. `process.env.PAYMENT_CLEANUP_DISABLED === '1'` → skip
2. `isRunning` 플래그 체크 → 동시 실행 차단
3. `paymentRepo.findPendingPaymentsOlderThan(24)` → stalePending 목록
4. 각 row: `paymentRepo.expirePayment(payment.id)` + `auditLog.log('system_cleanup', 'payment_expire', payment.id, { reason: 'pending_24h_cleanup', authorId, productId, createdAt, elapsedHours })`
5. 개별 row 실패 시 다음 row 처리 계속 (resilient)
6. finally: `isRunning = false`

### 변경 시 동시 갱신 대상

- `grimoire-server/src/application/payment/payment.usecase.ts` (initiatePayment 진입 게이트)
- `grimoire-server/src/application/payment/payment.usecase.spec.ts` (재사용 4 it 시나리오)
- `grimoire-server/src/application/payment/payment-cleanup.job.ts` (신설)
- `grimoire-server/src/application/payment/payment-cleanup.job.spec.ts` (신설)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.spec.ts` (신설 — `findReusablePendingPayment` ≥4 it)
- `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (시그니처)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (구현)
- `grimoire-server/src/app.module.ts` (PaymentCleanupJob DI)
- `grimoire-server/docs/api-contract.md` (재사용 정책 박제)
- `grimoire-server/docs/data-model.md` (Payment status enum 'expired' 사용 명세)
- `grimoire-server/INFRASTRUCTURE.md` §9 (cron 시간대 박제)
- `eval/tasks/regression-57-payment-retry-reuse.json`
- `.claude/scripts/sensor-payment-retry-reuse.sh`

### 변경 이력
- 2026-05-04 #10_7 PAY-P1-3: 신설 — `initiatePayment` 진입에 24h 이내 pending row 재사용 게이트 + 매일 새벽 4시 cleanup cron으로 만료 row 'expired' 마킹. DB schema 변경 0건. AuditLog operator='system_cleanup' + action='payment_expire'. 정본: `reports/sprint-pay-p1-3-retry-policy-progress.md`. server `findReusablePendingPayment` 시그니처는 PAY-P0-2 `findPendingPaymentsOlderThan` + PAY-P1-1 `refundPaymentAtomically` 패턴 정합.

---

## 15. SlugLogin (server + web 도메인 — slug 기반 로그인 마이그레이션)

**위치**:
- DTO: `grimoire-server/src/adapter/inbound/http/dto/auth.dto.ts` (`LoginDto` 확장 + `EmailXorSlugConstraint` validator)
- UseCase: `grimoire-server/src/application/auth/auth.usecase.ts` (`login(input)` 시그니처 + 분기, line 77-102)
- Controller: `grimoire-server/src/adapter/inbound/http/controller/auth.controller.ts` (AccessLog identifier 통합, line 86-89)
- Web Form: `grimoire-web/src/app/login/page.tsx` (입력칸 1개 통합 + 정규식 자동 판별)
- API client: `grimoire-web/src/lib/api.ts` (`login()` 시그니처 확장)
- AuthProvider: `grimoire-web/src/features/auth/AuthProvider.tsx` (`login(emailOrSlug, password, ...)`)
- E2E: `grimoire-web/e2e/auth.spec.ts` + `e2e/dashboard.spec.ts` + `.env.example` (`E2E_AUTHOR_SLUG`)

**적용**: 사용자가 이메일 또는 슬러그 + 비밀번호로 로그인 가능. 기존 email 로그인 후향호환 보존. DB schema 변경 0건 (Author.email/slug @unique 이미 박제).

### 시그니처

```typescript
// LoginDto (server)
class LoginDto {
  @IsOptional() @IsEmail() email?: string
  @IsOptional() @IsString() @Matches(/^[a-z0-9-]+$/) @MinLength(2) slug?: string
  @IsString() @MinLength(6) password!: string

  // class-level XOR validator — email 또는 slug 1택만 허용
  @Validate(EmailXorSlugConstraint)
  __emailXorSlug?: any
}

// AuthUseCase.login (server)
async login(input: { email?: string; slug?: string; password: string }) {
  if (input.email && input.slug) throw new BadRequestException('이메일 또는 슬러그 중 하나만 박제하세요')
  if (!input.email && !input.slug) throw new BadRequestException('이메일 또는 슬러그가 필요합니다')

  const author = input.email
    ? await this.authorRepo.findByEmail(input.email)
    : await this.authorRepo.findBySlug(input.slug!)

  if (!author || !author.passwordHash) throw new UnauthorizedException('이메일/슬러그 또는 비밀번호가 올바르지 않습니다')

  const valid = await bcrypt.compare(input.password, author.passwordHash)
  if (!valid) throw new UnauthorizedException('이메일/슬러그 또는 비밀번호가 올바르지 않습니다')

  // ... accessToken + refreshToken 발급
}

// API client login (web)
login(input: { email?: string; slug?: string; password: string }): Promise<AuthResponse>

// Web form 자동 판별 (login/page.tsx)
const isEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)
const payload = isEmail ? { email: trimmed, password } : { slug: trimmed, password }
```

### 정책

- **email XOR slug 1택 강제**: 둘 다 박제 시 BadRequestException + 둘 다 비어있으면 BadRequestException (DTO + UseCase 양 단계)
- **후향 호환**: 기존 email 로그인 그대로 동작 (회귀 0건)
- **DB schema 변경 0건**: Author.email/slug @unique 이미 박제됨
- **JWT payload 변경 0건**: sub=authorId + slug + role 이미 박제 (변경 불필요)
- **AccessLog identifier 통합**: schema 컬럼 변경 0 — AccessLog.email 컬럼은 양립 사용 (slug 로그인 시 slug 박제), detail에 `identifierType:email|slug` 박제
- **OAuth 자동 링크 정책 변경 0**: `auth.usecase.ts:100` `findByEmail` 자동 링크 그대로 (보안 위험 #1은 별도 sprint)
- **SignupHistory 정책 변경 0**: providerId=email 그대로 (위험 #2는 별도 sprint)
- **자동 판별 (web)**: 클라이언트 정규식 `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` 1차 판별 후 `{ email }` 또는 `{ slug }` payload 전송

### 처리 흐름 (Web Login Form → Server UseCase)

1. 사용자가 입력칸 1개 ("이메일 또는 슬러그")에 식별자 입력 + 비번 입력
2. `handleSubmit` 진입 시 `trim()` 후 정규식 `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` 판별
3. 매치 시 `{ email: trimmed, password }`, 미매치 시 `{ slug: trimmed, password }` payload
4. `POST /auth/login` (LoginDto) 전송
5. server LoginDto class-level XOR 검증 통과
6. `AuthUseCase.login(input)` 진입 → 도메인 XOR 검증 (transport 우회 차단)
7. `findByEmail(input.email) ?? findBySlug(input.slug)` 분기
8. 비번 bcrypt compare → accessToken + refreshToken 발급
9. AccessLog `identifierType:email|slug` detail 박제

### 변경 시 동시 갱신 대상

- `grimoire-server/src/adapter/inbound/http/dto/auth.dto.ts` (LoginDto + EmailXorSlugConstraint)
- `grimoire-server/src/application/auth/auth.usecase.ts` (login 시그니처)
- `grimoire-server/src/application/auth/auth.usecase.spec.ts` (slug 로그인 6 it)
- `grimoire-server/src/adapter/inbound/http/controller/auth.controller.ts` (AccessLog identifierType detail)
- `grimoire-web/src/app/login/page.tsx` (입력칸 통합 + 자동 판별)
- `grimoire-web/src/lib/api.ts` (login 시그니처)
- `grimoire-web/src/features/auth/AuthProvider.tsx` (login 시그니처)
- `grimoire-web/e2e/auth.spec.ts` + `e2e/dashboard.spec.ts` (E2E_AUTHOR_SLUG 양립)
- `grimoire-web/.env.example` (E2E_AUTHOR_SLUG=deerdevil)
- `grimoire-server/docs/api-contract.md` (POST /auth/login 갱신)
- `eval/tasks/regression-59-slug-login.json`
- `.claude/scripts/sensor-slug-login.sh`

### 변경 이력
- 2026-05-05 #10_7 EMAIL-P0-3: 신설 — slug 로그인 마이그레이션. Phase 1 server (LoginDto XOR + login 분기 + AccessLog identifierType + spec 6 it) + Phase 2 web (입력칸 통합 + 자동 판별 + e2e + .env.example). DB schema 변경 0건. 후향호환 보존 (email 로그인 회귀 0). 정본: `research/EMAIL_INTEGRITY_PLAN.md` §13 + `reports/sprint-email-p0-3-slug-login-progress.md`.

---

## 16. OAuthEmailVerification (server 도메인 — OAuth 자동 링크 보안 강화 강화안 A)

**위치**:
- UseCase: `grimoire-server/src/application/auth/auth.usecase.ts` `googleLogin(googleToken)` 메서드 line 112-122 (email_verified 차단 게이트)
- Spec: `grimoire-server/src/application/auth/auth.usecase.spec.ts` `describe('googleLogin (트랙 F email_verified 차단)')` 4 it 박제
- Sensor: `.claude/scripts/sensor-oauth-email-verification.sh` (8 검증)
- Regression task: `eval/tasks/regression-60-oauth-email-verification.json` (10 criteria)
- 정본: `reports/sprint-oauth-email-verification-progress.md`

**적용**: Google OAuth 로그인 시 `payload.email_verified === false`이면 즉시 `UnauthorizedException` 발생 — 자동 계정 링크(`findByEmail` → `linkSocialAccount`) 차단으로 victim 이메일의 미인증 OAuth 계정이 기존 일반 회원 계정을 인수하는 위험 차단 (RFC 6819 §5.1.1, OWASP A07:2021).

### 시그니처

```typescript
async googleLogin(googleToken: string) {
  const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID)
  const ticket = await client.verifyIdToken({ idToken: googleToken, audience: process.env.GOOGLE_CLIENT_ID })
  const payload = ticket.getPayload()
  if (!payload?.email) throw new UnauthorizedException('Google 인증 실패')

  // 트랙 F 강화안 A — RFC 6819 §5.1.1 / OWASP A07:2021 자동 링크 차단
  if (payload.email_verified === false) {
    throw new UnauthorizedException(
      'Google 이메일이 아직 인증되지 않았습니다. Google 계정에서 이메일 인증 후 다시 시도해주세요.',
    )
  }

  // 이후 findBySocialAccount → findByEmail → linkSocialAccount 순으로 진행 (위 게이트 통과 후)
  let author = await this.authorRepo.findBySocialAccount('google', payload.sub!)
  // ...
}
```

### 정책

- **`email_verified === false` → UnauthorizedException**: 명시 false만 차단. `undefined` (필드 미박제)는 통과 (Google 기본 verified=true 정합).
- **차단 게이트 위치**: `findBySocialAccount` 호출 **앞에** 위치 강제 — 자동 링크 시도 자체 차단. sensor가 line 비교로 정합 검증.
- **기존 사용자 영향 0**: Google은 기본 `email_verified=true` 반환 → 정상 사용자 회귀 0.
- **외부 API 신규 의존 0건**: 절대 규정 0-1 정합 (이미 사용 중인 google-auth-library 내부 필드만 활용).
- **사용자 메시지 한국어 존댓말**: Constitution P10 정합 — "Google 이메일이 아직 인증되지 않았습니다."
- **향후 확장**: Kakao/Naver OAuth 도입 시 (EMAIL-P1-2) 각 provider의 verified 필드 확인 + 미존재 시 강화안 C(이메일 검증 발송) 강제 진입.

### 처리 흐름 (Google ID token → 차단 / 통과)

1. 클라이언트가 Google ID token + `POST /auth/google`
2. `googleLogin(googleToken)` 진입 → `OAuth2Client.verifyIdToken` Google JWT 검증
3. `payload = ticket.getPayload()` 추출 (email / email_verified / sub / name)
4. `payload.email` 누락 → `UnauthorizedException('Google 인증 실패')`
5. **`payload.email_verified === false` → `UnauthorizedException('Google 이메일이 아직 인증되지 않았습니다...')`**
6. 통과 시 `findBySocialAccount('google', payload.sub)` → 기존 연결 author 검색
7. 미존재 시 `findByEmail(payload.email)` → 자동 링크 후보 검색
8. 미존재 시 신규 가입 (slug 자동 생성 + 가입 보너스 3 크레딧)
9. `linkSocialAccount` 호출 + accessToken/refreshToken 발급

### 변경 시 동시 갱신 대상

- `grimoire-server/src/application/auth/auth.usecase.ts` (line 112-122 차단 게이트)
- `grimoire-server/src/application/auth/auth.usecase.spec.ts` (`describe('googleLogin')` 4 it: payload.email 누락 / email_verified=false / email_verified=true 회귀 / email_verified undefined 통과)
- `.claude/scripts/sensor-oauth-email-verification.sh` (8 검증)
- `eval/tasks/regression-60-oauth-email-verification.json` (10 criteria)
- `reports/sprint-oauth-email-verification-progress.md` (정본)
- `research/EMAIL_INTEGRITY_PLAN.md` §13-5 #1 상태 표 (해소됨 박제)
- `grimoire-server/SECURITY.md` (향후 §2 OAuth 검증 정책 추가)

### 변경 이력
- 2026-05-05 #10_7 트랙 F 강화안 A: 신설 — OAuth 자동 링크 보안 강화 1단계. `email_verified === false` 차단 게이트 + spec 4 it (16/16 PASS) + sensor (8/8 PASS) + regression-60. 외부 API 신규 의존 0건 (절대 규정 0-1 정합). 강화안 B(명시 동의) / C(이메일 인증 발송)는 EMAIL-P1-1 후 별도 sprint.

---

## 17. PartialRefund (server 도메인 — PAY-P2-1 부분 환불 비율 계산)

**위치**:
- Port: `grimoire-server/src/domain/port/outbound/payment-repository.port.ts:79-100` (반환 타입 4 필드 확장)
- Repository: `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts:117-220` (`refundPaymentAtomically` 비율 계산 보강)
- UseCase: `grimoire-server/src/application/payment/refund-payment.usecase.ts:40-130` (4 action 매트릭스)
- Spec: `grimoire-server/src/application/payment/refund-payment.usecase.spec.ts` (`describe('부분 환불 (PAY-P2-1)')` 6 it 추가, 16/16 PASS)
- Sensor: `.claude/scripts/sensor-partial-refund.sh` (10 검증)
- Regression: `eval/tasks/regression-61-partial-refund.json` (10 criteria)
- 정본: `reports/sprint-pay-p2-1-partial-refund-progress.md` + `reports/PAY-P2-MASTER-PLAN.md` §3

**적용**: Polar 환불 webhook (`order.refunded`) 또는 운영자 수동 부분 환불 시 `refundedAmount` 비율에 따라 크레딧을 비례 차감. PAY-P1-1 전액 환불 회귀 보존 + 부분 환불 신규 수용. RefundLog 호환성은 PAY-P1-1 박제 시점부터 이미 확보 (UNIQUE 미부여, amount/credits 분리 설계).

### 시그니처

```typescript
// PaymentRepositoryPort (반환 타입 확장)
refundPaymentAtomically(input: {
  paymentId: string
  authorId: string
  credits: number          // 원래 결제 적립 크레딧 (양수 — 비율로 비례 차감)
  refundedAmount: number   // 전액 시 payment.amount, 부분 시 그 미만
  reason: string
  source: 'webhook' | 'manual'
}): Promise<{
  actualDeducted: number       // 실제 차감 크레딧 (deficit 시 잔액)
  deficitCredits: number       // 잔액 부족분
  proportionalCredits: number  // ★ 신규 — 비율 적용 후 차감 목표
  isPartial: boolean           // ★ 신규 — 부분 환불 여부 (ratio < 1.0)
}>

// RefundPaymentUseCase.execute (반환 타입 확장 + action 4 매트릭스)
async execute(input): Promise<{
  actualDeducted: number
  deficitCredits: number
  proportionalCredits: number
  isPartial: boolean
}>
```

### 정책

- **비율 계산 (트랜잭션 내부)**: `ratio = refundedAmount / payment.amount` (`prisma-payment.repository.ts`)
- **비례 크레딧**: `proportionalCredits = isPartial ? Math.floor(credits * ratio) : credits`
- **반올림 정책**: `Math.floor` 고정 (사용자 우호 — 차감 ↓ 소수점 버림)
- **isPartial 분기**: `ratio < 1.0` (전액 환불은 PAY-P1-1 회귀 보존)
- **Payment.status 분기**: 부분 환불 시 `'partial_refunded'`, 전액 시 `'refunded'`
- **Validation**:
  - `refundedAmount <= 0` → `BadRequestException` (usecase)
  - `payment.amount <= 0` → throw (free 결제 환불 무의미)
  - `refundedAmount > payment.amount` → throw (validation)
- **AuditLog action 4 매트릭스** (isPartial × deficitCredits):
  - `refund_normal` (전액 + 정상)
  - `refund_deficit` (전액 + deficit)
  - `refund_partial` (부분 + 정상)
  - `refund_partial_deficit` (부분 + deficit)
- **CreditLog reason 접미사**: 부분 환불 시 `_partial` 추가 (`refund_<paymentId>_<source>_partial`)
- **deficit 분기**: 부분 환불 시 proportionalCredits 기준으로 deficit 계산 (잔액 < proportionalCredits)

### 처리 흐름 (Polar order.refunded → 비율 계산 → 차감)

1. Polar webhook → `polar.adapter.verifyAndParseWebhook` → `NormalizedWebhookEvent { type:'order.refunded', amount, ... }`
2. `payment.usecase.processWebhook` → `event.status === 'cancel'` 분기 → `refundPaymentUseCase.execute`
3. `refundPaymentUseCase.execute` → `paymentRepo.refundPaymentAtomically` 호출
4. `prisma-payment.repository.refundPaymentAtomically` $transaction:
   - tx.payment.findUnique → amount 조회
   - validation (refundedAmount > 0, payment.amount > 0, refundedAmount ≤ payment.amount)
   - ratio = refundedAmount / payment.amount
   - isPartial = ratio < 1.0
   - proportionalCredits = isPartial ? Math.floor(credits * ratio) : credits
   - tx.payment.update → status='partial_refunded'|'refunded'
   - tx.author.findUnique → currentBalance 조회
   - actualDeducted = Math.min(currentBalance, proportionalCredits)
   - deficitCredits = Math.max(0, proportionalCredits - currentBalance)
   - tx.author.update → credits decrement (actualDeducted > 0 시만)
   - tx.creditLog.create → amount=-actualDeducted (대칭, `_partial` 접미사)
   - tx.refundLog.create → amount=refundedAmount + credits=actualDeducted + deficitCredits
5. UseCase 반환 후 AuditLog 후행 (4 action 매트릭스 분기)

### 변경 시 동시 갱신 대상

- `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (시그니처)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (구현)
- `grimoire-server/src/application/payment/refund-payment.usecase.ts` (action 매트릭스)
- `grimoire-server/src/application/payment/refund-payment.usecase.spec.ts` (부분 환불 6 it + 기존 7 it 시그니처 갱신)
- `.claude/scripts/sensor-partial-refund.sh` (10 검증)
- `eval/tasks/regression-61-partial-refund.json` (10 criteria)
- `reports/sprint-pay-p2-1-partial-refund-progress.md` (정본)

### 변경 이력
- 2026-05-05 #10_7 PAY-P2-1: 신설 — 부분 환불 비율 계산 sprint. 외부 API 신규 의존 0건 (Polar webhook 내부 amount 필드만 활용). RefundLog 호환성은 PAY-P1-1 박제 시점부터 이미 확보. 회귀: PAY-P1-1 전액 환불 spec 7건 모두 PASS (16/16 jest + 10/10 sensor + 10/10 regression-61). 정본: PAY-P2 마스터 플랜 §3.

---

## 18. WebhookDLQ (server 도메인 — PAY-P2-2 Postgres 기반 webhook 재시도 큐)

**위치**:
- Schema: `grimoire-server/prisma/schema.prisma` (`model WebhookRetryQueue`)
- Migration: `grimoire-server/prisma/migrations/20260505020000_add_webhook_retry_queue/migration.sql`
- Port: `grimoire-server/src/domain/port/outbound/webhook-retry-queue-repository.port.ts` (5 메서드)
- Repository: `grimoire-server/src/adapter/outbound/persistence/prisma-webhook-retry-queue.repository.ts` (P2002 race 안전)
- Job: `grimoire-server/src/application/payment/webhook-retry.job.ts` (`@Cron('0 */5 * * * *')` 5분 주기)
- Spec: `grimoire-server/src/application/payment/webhook-retry.job.spec.ts` (8 it, 8/8 PASS)
- Sensor: `.claude/scripts/sensor-webhook-dlq.sh` (12 검증)
- Regression: `eval/tasks/regression-62-webhook-dlq.json` (12 criteria)
- 정본: `reports/sprint-pay-p2-2-webhook-dlq-progress.md` + `reports/PAY-P2-MASTER-PLAN.md` §4

**적용**: `payment.usecase.processWebhook` 실패 분기(success 트랜잭션 실패 + cancel/refund 실패)에서 `webhook_retry_queues` 테이블에 멱등 박제(eventId @unique). `WebhookRetryJob` @Cron 5분이 `nextRetryAt <= now()` row를 재처리. 외부 인프라 의존 0건 (Postgres만, 절대 규정 0-1 정합).

### 시그니처

```typescript
// Schema
model WebhookRetryQueue {
  id          String   @id @default(uuid())
  eventId     String   @unique @map("event_id")
  payload     Json
  retryCount  Int      @default(0) @map("retry_count")
  lastError   String?  @map("last_error")
  nextRetryAt DateTime @map("next_retry_at") @db.Timestamptz(3)
  createdAt   DateTime @default(now()) @map("created_at") @db.Timestamptz(3)
  @@index([nextRetryAt])
  @@map("webhook_retry_queues")
}

// Port (5 메서드)
interface WebhookRetryQueueRepositoryPort {
  upsert(input: { eventId; payload; nextRetryAt }): Promise<Record | null>  // P2002 시 null
  findDue(now: Date, limit?: number): Promise<Record[]>                     // ORDER BY nextRetryAt LIMIT N
  deleteById(id: string): Promise<void>
  markRetry(id: string, error: string, nextRetryAt: Date): Promise<void>    // retryCount++
  findByEventId(eventId: string): Promise<Record | null>
}

// Job (@Cron 5분)
@Cron('0 */5 * * * *')
async retryDueWebhooks(): Promise<void>

// PaymentUseCase 신규 메서드
async processNormalizedWebhook(event: NormalizedWebhookEvent): Promise<{
  processed: boolean
  credits?: number
  deficitCredits?: number
  reason?: string
}>
```

### 정책

- **멱등성 키**: `eventId @unique` (webhook_events.eventId와 정합 — 같은 webhook은 한 큐 row만)
- **race 안전**: `upsert` P2002 시 null 반환 (기존 row 보존, retryCount는 markRetry로만 증가)
- **백오프 매트릭스 (분 단위)**:
  - retryCount=1 → 1분
  - retryCount=2 → 5분
  - retryCount=3 → 30분
  - retryCount=4 → 120분 (2h)
  - retryCount=5 → 720분 (12h)
  - retryCount=6+ → 1440분 (24h)
- **MAX_RETRY=10**: 초과 시 webhook_events status='failed' 갱신 + AuditLog operator='system_dlq' + queue row 삭제
- **isRunning lock**: 같은 process 내 동시 실행 차단 (replicas ≥2 시 advisory_lock 보강 보류)
- **비활성화 게이트**: `WEBHOOK_RETRY_DISABLED=1` env 시 즉시 return
- **BATCH_SIZE=100**: 한 cron tick 최대 처리 row 수
- **Optional 의존**: payment.usecase는 `@Optional()` 주입으로 retryQueueRepo 미주입 시 회귀 보존 (기존 동작 유지)
- **payment.usecase 분리**: `processWebhook(rawBody, headers)` (verify) + `processNormalizedWebhook(event)` (DB 처리). retry 시점에는 verify 우회.

### 처리 흐름 (실패 → 재시도 → 성공/permanent_failed)

1. Polar webhook → `payment.usecase.processWebhook(rawBody, headers)` 진입
2. `verifyAndParseWebhook` → `processNormalizedWebhook(event)` 호출
3. `completePaymentAtomically` (success) 또는 `refundPaymentUseCase.execute` (cancel) 트랜잭션 실패
4. catch 블록: `webhook_events.createIfAbsent(status='failed')` + `enqueueWebhookRetry(event, eventId)`
5. `webhook_retry_queues.upsert({ eventId, payload, nextRetryAt: now+1m })` (P2002 시 null 반환, race 안전)
6. throw → caller가 webhook 응답 500 → Polar 자체 재전송 + 본 큐의 자체 cron 재시도 (이중 보호)
7. `WebhookRetryJob` 5분 주기 진입:
   - `findDue(now)` → due row 100건 조회
   - 각 row → `processNormalizedWebhook(event)` 호출
   - 성공 → `deleteById(id)` (큐 row 제거)
   - 실패 (retryCount+1 < 10) → `markRetry(id, error, calcNextRetry(retryCount+1))`
   - 실패 (retryCount+1 ≥ 10) → `webhookEventRepo.markStatus('failed')` + `auditLog.log('system_dlq', 'webhook_permanent_failed')` + `deleteById(id)`

### 변경 시 동시 갱신 대상

- `grimoire-server/prisma/schema.prisma` (model)
- `grimoire-server/prisma/migrations/20260505020000_add_webhook_retry_queue/migration.sql`
- `grimoire-server/src/domain/port/outbound/webhook-retry-queue-repository.port.ts`
- `grimoire-server/src/adapter/outbound/persistence/prisma-webhook-retry-queue.repository.ts`
- `grimoire-server/src/application/payment/webhook-retry.job.ts`
- `grimoire-server/src/application/payment/webhook-retry.job.spec.ts`
- `grimoire-server/src/application/payment/payment.usecase.ts` (Optional 주입 + processNormalizedWebhook 분리 + enqueueWebhookRetry)
- `grimoire-server/src/app.module.ts` (WebhookRetryJob + WebhookRetryQueueRepositoryPort 등록)
- `.claude/scripts/sensor-webhook-dlq.sh`
- `eval/tasks/regression-62-webhook-dlq.json`
- `reports/sprint-pay-p2-2-webhook-dlq-progress.md`

### 변경 이력
- 2026-05-05 #10_7 PAY-P2-2: 신설 — Postgres 기반 webhook DLQ. 외부 인프라 의존 0건 (Redis/ServiceBus/Kafka 미사용). schema +1 모델 + migration 1건. payment.usecase processWebhook → processNormalizedWebhook 분리 (retry 시점 verify 우회). spec 8/8 + sensor 12/12 + jest server 583→591. 정본: PAY-P2 마스터 플랜 §4 + reports/sprint-pay-p2-2-webhook-dlq-progress.md.

---

## 19. SmsServicePort (server 도메인 — PAY-P2-3 사전 작업: SMS Hexagonal 캡슐화)

**위치**:
- Port: `grimoire-server/src/domain/port/outbound/sms-service.port.ts` (4 메서드 — sendPaymentNotification/sendVerificationCode/isEnabled/getProviderName)
- Adapter (default): `grimoire-server/src/adapter/outbound/sms/null-sms.adapter.ts` (외부 API 0건, PII 마스킹)
- Spec: `grimoire-server/src/adapter/outbound/sms/null-sms.adapter.spec.ts` (10/10 PASS)
- Sensor: `.claude/scripts/sensor-sms-service-port.sh` (8 검증)
- Regression: `eval/tasks/regression-63-sms-service-port.json` (10 criteria)
- 정본: `reports/sprint-pay-p2-3-sms-service-port-progress.md` + `reports/PAY-P2-MASTER-PLAN.md` §5

**적용**: SMS provider 캡슐화 (Hexagonal) — UseCase는 본 인터페이스만 의존. 절대 규정 0-1 (외부 API 신규 의존) **사용자 명시 해제 전까지 NullSmsAdapter default**. 결정 후 KakaoBizmessageAdapter / NhnCloudAdapter / TwilioAdapter 어댑터만 추가. EmailServicePort §12와 동일 패턴 정합.

### 시그니처

```typescript
// Port 인터페이스
export type SmsProvider = 'null' | 'kakao' | 'nhn' | 'twilio'
export type PaymentSmsType = 'payment_success' | 'payment_failed' | 'payment_refunded'

export interface SmsSendResult {
  messageId: string | null
  provider: SmsProvider
}

export interface SmsServicePort {
  sendPaymentNotification(input: {
    to: string
    type: PaymentSmsType
    displayName?: string
    payload: Record<string, unknown>
  }): Promise<SmsSendResult>

  sendVerificationCode(input: {
    to: string
    code: string
    displayName?: string
    expireAt: Date
  }): Promise<SmsSendResult>

  isEnabled(): boolean
  getProviderName(): SmsProvider
}
```

### 정책

- **default Provider = 'null'**: env 미박제 시 NullSmsAdapter — `isEnabled()=false` 반환, 실 발송 0건, logger.warn만.
- **PII 마스킹 강제**: 전화번호 (`+821****5678`), 인증코드 (`1***`) — 평문 박제 차단 (PIPA / GDPR 정합).
- **외부 SDK import 0건**: 절대 규정 0-1 정합. provider 결정 시 별도 sprint에서 어댑터만 추가.
- **EmailServicePort 패턴 정합**:
  - PaymentSmsType ↔ PaymentNotificationType 동일 3 타입 (success/failed/refunded)
  - sendPaymentNotification 시그니처 동일 형태 (`to + type + displayName + payload`)
- **결제 트리거 미연동 (의도된 OUT)**: payment.usecase에 sendPaymentNotification 호출 박제 0건. EMAIL-P1-3 / PAY-P2-3 진입 시 한 번에 통합 (Email + SMS 동시 알림).
- **app.module DI 미등록 (의도된 OUT)**: EmailServicePort와 동일 패턴 — 캡슐화 + spec만 박제. provider 결정 후 별도 sprint에서 등록.
- **payload 키 매트릭스** (EmailServicePort 정합):
  - `payment_success`: { paymentId, amount, credits, productName }
  - `payment_failed`: { paymentId, amount, productName }
  - `payment_refunded`: { paymentId, refundedAmount, credits, deficitCredits, reason, isPartial }

### 처리 흐름 (provider 결정 후 + 트리거 진입 시 예상)

```
PAY 트랜잭션 (success / refund) commit 후
  → EmailServicePort.sendPaymentNotification (이미 캡슐화)
  → SmsServicePort.sendPaymentNotification (본 캡슐화)
  → 둘 다 NullAdapter면 noop (logger.warn만)
  → 사용자가 "이메일 SaaS 진입" + "SMS 진입" 명시 후
    → ResendEmailAdapter / KakaoBizmessageAdapter 등으로 교체
    → UseCase 코드 변경 0건 (인터페이스만 의존)
```

### 변경 시 동시 갱신 대상

- `grimoire-server/src/domain/port/outbound/sms-service.port.ts` (Port 인터페이스)
- `grimoire-server/src/adapter/outbound/sms/null-sms.adapter.ts` (default 어댑터)
- `grimoire-server/src/adapter/outbound/sms/null-sms.adapter.spec.ts` (10 it)
- `.claude/scripts/sensor-sms-service-port.sh` (8 검증)
- `eval/tasks/regression-63-sms-service-port.json` (10 criteria)
- `reports/sprint-pay-p2-3-sms-service-port-progress.md` (정본)
- 향후 진입 시 추가:
  - `grimoire-server/src/adapter/outbound/sms/kakao-bizmessage.adapter.ts` (사용자 결정 후)
  - `grimoire-server/src/app.module.ts` (DI factory + env 분기)
  - `grimoire-server/src/application/payment/payment.usecase.ts` (트리거 호출)

### 변경 이력
- 2026-05-05 #10_7 PAY-P2-3 사전 작업: 신설 — SMS Hexagonal Port 캡슐화. 외부 API 신규 의존 0건 (NullSmsAdapter default + 외부 SDK import 0건). 절대 규정 0-1 정합. EmailServicePort 패턴 차용. spec 10/10 + sensor 8/8 + regression-63. 결제 트리거 + app.module DI 등록은 SMS provider 사용자 결정 후 별도 sprint 진입.

---

## 20. AdminAuditLog beforeState/afterState Convention (server 도메인 — PAY-P2-4 정밀화)

**위치**:
- Service: `grimoire-server/src/application/admin/audit-log.service.ts` (`log()` 시그니처 6-arg BACKWARD COMPATIBLE 확장, line 22-49)
- Spec: `grimoire-server/src/application/admin/audit-log.service.spec.ts` (신설 10 it)
- 호출처:
  - `application/admin/admin.usecase.ts` (grantCredits + deductCredits, line 93-129)
  - `application/payment/payment.usecase.ts` (processWebhook 'success' 'payment_completed', line 188-247)
  - `application/payment/refund-payment.usecase.ts` (4 action: refund_normal/deficit/partial/partial_deficit, line 75-170)

**적용**: 모든 audit log 호출 시 detail JSON에 표준 키 `beforeState` + `afterState` 박제. 감사 추적 시 변경 전/후 값 명시적 박제로 회귀/부정행위 식별 가능. DB schema 변경 0건 (AdminAuditLog.detail JSON 컬럼 활용).

### 시그니처 (BACKWARD COMPATIBLE)

```typescript
async log(
  operator: string,           // 'admin:{id}' | 'system_payment' | 'system_refund' | 'system_cleanup' | 'system_reconciliation'
  action: string,             // 'credit_grant' | 'credit_deduct' | 'payment_completed' | 'refund_normal' | ...
  targetId: string,
  detail?: Record<string, unknown>,
  beforeState?: Record<string, unknown>,  // PAY-P2-4 신규 — optional, BACKWARD COMPATIBLE
  afterState?: Record<string, unknown>,   // PAY-P2-4 신규 — optional, BACKWARD COMPATIBLE
): Promise<void>

// 4-arg 호출 — 기존 패턴 유지 (회귀 0)
auditLog.log('system_refund', 'refund_normal', paymentId, { reason })

// 6-arg 호출 — PAY-P2-4 신규 패턴
auditLog.log(
  'admin:admin-1', 'credit_grant', authorId,
  { reason: 'manual grant' },
  { credits: 100 }, { credits: 150 },
)
```

### 정책 (action별 표준 매트릭스)

| action | operator | beforeState | afterState |
|---|---|---|---|
| `credit_grant` | `admin:{id}` | `{ credits: oldBalance }` | `{ credits: newBalance }` |
| `credit_deduct` | `admin:{id}` | `{ credits: oldBalance }` | `{ credits: newBalance }` |
| `payment_completed` | `system_payment` | `{ credits: balanceBefore }` | `{ credits: balanceAfter, paymentId, addedCredits }` |
| `refund_normal` | `system_refund` | `{ credits, paymentStatus: 'completed' }` | `{ credits, paymentStatus: 'refunded', deficitCredits: 0, creditsActuallyDeducted }` |
| `refund_deficit` | `system_refund` | `{ credits, paymentStatus: 'completed' }` | `{ credits: 0, paymentStatus: 'refunded', deficitCredits, creditsActuallyDeducted }` |
| `refund_partial` | `system_refund` | `{ credits, paymentStatus: 'completed' }` | `{ credits, paymentStatus: 'partial_refunded', deficitCredits: 0, creditsActuallyDeducted }` |
| `refund_partial_deficit` | `system_refund` | `{ credits, paymentStatus: 'completed' }` | `{ credits: 0, paymentStatus: 'partial_refunded', deficitCredits, creditsActuallyDeducted }` |
| `payment_expire` | `system_cleanup` | (생략 — pending row 만료, 잔액 변경 0) | (생략) |

### 처리 흐름

1. `log()` 진입
2. `hasBefore = beforeState !== undefined` / `hasAfter = afterState !== undefined`
3. detail JSON 빌드: `detail` spread + `hasBefore` true → `beforeState` 키 추가 + `hasAfter` true → `afterState` 키 추가
4. 둘 다 undefined → detail JSON에 키 미박제 (4-arg 호출 회귀 0)
5. AdminAuditLog DB INSERT (detail JSON 컬럼 활용)

### 변경 시 동시 갱신 대상

- `audit-log.service.ts` (시그니처)
- `audit-log.service.spec.ts` (신설 ≥6 it)
- `admin.usecase.ts` (grantCredits + deductCredits)
- `payment.usecase.ts` (processWebhook 'success')
- `refund-payment.usecase.ts` (4 action)
- 위 4개 spec 파일 (회귀 보존 + 검증 강화)
- `eval/tasks/regression-64-audit-log-before-after.json`
- `.claude/scripts/sensor-audit-log-before-after.sh`

### 변경 이력
- 2026-05-06 #10_8 (다른 세션 + 본 세션 공동) PAY-P2-4: 신설 — AuditLogService.log() 6-arg BACKWARD COMPATIBLE 확장 + admin.usecase + payment.usecase + refund-payment.usecase 호출처 갱신 + audit-log.service.spec 신설 10 it. PAY-P1-1 refund spec 16 it 회귀 0건 보존. DB schema 변경 0건. 정본: `reports/sprint-pay-p2-4-audit-strengthening-progress.md` + `.claude/shared-contracts.md §20`. 검증: jest server 604→625 (+21), sensor 10/10 PASS, 의미 있는 assertion 19건.

---

## 21. InfraMutationGuard (.claude 도메인 — 인프라 변경 안전망)

**위치**:
- Skill: `.claude/skills/infra-mutation-guard/SKILL.md` (다른 세션 5/6 박제, disable-model-invocation:true)
- Skill: `.claude/skills/rollback-revision/SKILL.md` (다른 세션 5/6 박제, destructive infra)
- Sensor: `.claude/scripts/sensor-deploy-health.sh` (INFRA-1 신설, 5 검증)
- Sensor: `.claude/scripts/sensor-azure-env-secret.sh` (INFRA-1 신설, 8 시크릿 + PUBLIC_API_BASE_URL + Polar env 14건 검증)

**적용**: Azure Container Apps 인프라 변경 (image / env / secret / revision activate-deactivate) 직전·직후 health 자동 검증 + 운영 환경 미검증 패턴 차단. PAY-P1-1+P1-3+EMAIL-P0-3+다른 세션 #10_8 §0 거짓 검증 매트릭스 회고 정합.

### 트리거 (skill)

```yaml
triggers:
  - "az containerapp update"
  - "az containerapp set-env-vars"
  - "az containerapp secret set"
  - "az containerapp revision activate"
  - "main 머지 진행"
  - "prod 배포"
  - "Container Apps 변경"
  - "rollback"
  - "revision 회복"
```

### sensor-deploy-health 검증 영역 (5건)

1. 신규 revision HealthState=Healthy
2. Traffic=100%
3. RunningState (RunningAtMaxScale / Running / ScaledToZero / Activating 분기)
4. curl public endpoint HTTP 200/307
5. startup time ≤120s (Cloudflare 524 회피)

Exit codes: 0 PASS / 1 WARN (Activating/ScaledToZero) / 2 FAIL (Healthy != true 또는 Failed)

### sensor-azure-env-secret 검증 영역 (14건)

8 시크릿 secretRef 매트릭스:
- DATABASE_URL / JWT_SECRET / RECAPTCHA_SECRET_KEY / ANTHROPIC_API_KEY / OPENAI_API_KEY / POLAR_ACCESS_TOKEN / POLAR_WEBHOOK_SECRET / AZURE_STORAGE_ACCOUNT_KEY

추가 env 박제 검증:
- **PUBLIC_API_BASE_URL** (dev 153 ActivationFailed 회귀 차단 핵심)
- POLAR_SERVER + POLAR_ORGANIZATION_ID + POLAR_PRODUCT_BASIC/POPULAR/BEST (Polar 정합)
- CORS_ORIGIN (BFF 정합)

### 정책

- **인프라 변경 직전 health snapshot 강제** (infra-mutation-guard skill Step 1)
- **변경 후 3-stage polling** (10s/30s/60s)
- **Failure 검출 시 자동 rollback 권고** (rollback-revision skill 호출)
- **운영 환경 검증 필수** (코드 spec PASS만으로 "검증 완료" 보고 차단)
- **PUBLIC_API_BASE_URL 누락 = startup fail** — sensor 강제 검증

### 처리 흐름 (배포 직전 → 직후)

1. `infra-mutation-guard` skill Step 1: pre-mutation health snapshot 박제 + last_healthy_revision 식별
2. mutation 실행 (사용자 명시 명령)
3. Step 3 polling 3-stage: 10s/30s/60s 후 신규 revision health 검증
4. `sensor-deploy-health` 자동 호출 (5 검증)
5. `sensor-azure-env-secret` 자동 호출 (14 검증)
6. Failure 시 `rollback-revision` skill 즉시 호출 권고

### 변경 시 동시 갱신 대상

- `.claude/skills/infra-mutation-guard/SKILL.md` (이미 박제)
- `.claude/skills/rollback-revision/SKILL.md` (이미 박제)
- `.claude/scripts/sensor-deploy-health.sh` (INFRA-1 신설)
- `.claude/scripts/sensor-azure-env-secret.sh` (INFRA-1 신설)
- `eval/tasks/regression-65-infra-mutation-guard.json` (INFRA-1 신설)
- `reports/sprint-infra-1-mutation-guard-progress.md` (Sprint progress)

### 변경 이력
- 2026-05-08 INFRA-1: 신설 — prod revision 97 ActivationFailed 사고 직후 사용자 분노 정합 ("다 고쳐놔"). sensor-deploy-health + sensor-azure-env-secret 신설. **즉시 가치 입증**: sprint 신설 30초 후 prod PUBLIC_API_BASE_URL 누락 정확 검출 (revision 97 Failed 사유 정확 진단). 정본: `reports/sprint-infra-1-mutation-guard-progress.md`.

---

## 22. PaymentRaceCondition (server 도메인 — 결제 race condition 차단)

**위치**:
- UseCase: `grimoire-server/src/application/payment/payment.usecase.ts` (`processNormalizedWebhook` 사전 게이트)
- UseCase: `grimoire-server/src/application/payment/refund-payment.usecase.ts` (호출자 정합)
- Repository: `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (`refundPaymentAtomically` CAS)
- Sensor: `.claude/scripts/sensor-payment-race-condition.sh` (8 검증)

**적용**: PAYMENT_AUDIT §1 구멍-A (eventId 다른 type 동시 처리 누락) + 구멍-B (transaction race — `Author.findUnique → update decrement` READ COMMITTED 격리 race window) 동시 차단. DB schema 변경 0건. 외부 인프라 의존 0건. PAY-P2-2 DLQ retry 패턴 정합.

### 시그니처 — 사전 게이트 (구멍-A 차단)

```typescript
// payment.usecase.ts processNormalizedWebhook 진입 직후 (already_completed 게이트 다음)
if (payment.status === 'refunded' || payment.status === 'partial_refunded') {
  const reasonKey = `already_${payment.status}` as 'already_refunded' | 'already_partial_refunded'
  this.logger.warn(
    `[PaymentRaceCondition] ${reasonKey} eventId=${event.eventId} paymentId=${payment.id}`,
  )
  await this.webhookEventRepo.createIfAbsent({
    eventId: event.eventId,
    source: 'polar',
    eventType: event.type,
    payload: event as unknown as object,
    status: 'skipped',
    errorMessage: reasonKey,
  })
  return { processed: false, reason: reasonKey }
}
```

### 시그니처 — CAS 패턴 (구멍-B 차단)

```typescript
// prisma-payment.repository.ts refundPaymentAtomically $transaction 내부
const author = await tx.author.findUniqueOrThrow({
  where: { id: authorId },
  select: { credits: true },
})
const currentBalance = author.credits
const actualDeducted = Math.min(currentBalance, proportionalCredits)
const deficitCredits = Math.max(0, proportionalCredits - currentBalance)

if (actualDeducted > 0) {
  // CAS 패턴 — Postgres atomic check-and-set (race window 차단)
  const updateResult = await tx.author.updateMany({
    where: {
      id: authorId,
      credits: { gte: actualDeducted },
    },
    data: { credits: { decrement: actualDeducted } },
  })
  if (updateResult.count === 0) {
    throw new Error(
      `CAS_MISMATCH — race condition detected on author.credits (authorId=${authorId}, expected_min=${actualDeducted})`,
    )
  }
}
```

### 정책

- **사전 게이트 (구멍-A)**: payment.status='refunded' OR 'partial_refunded' → skip (이미 환불 완료된 payment에 대한 재처리 방어 — 환불 후 재차감 0건 보장)
- **CAS 패턴 (구멍-B)**: `updateMany WHERE credits >= actualDeducted` (Postgres atomic CAS) → 0 row 시 throw 'CAS_MISMATCH' → 호출자 retry 위임 (PAY-P2-2 DLQ)
- **격리 수준**: $transaction은 READ COMMITTED (Postgres 기본). CAS 패턴이 격리 부족분을 보강.
- **재시도 위임**: CAS_MISMATCH throw → refund-payment.usecase 또는 payment.usecase catch → webhookEventRepo 'failed' + DLQ enqueue → WebhookRetryJob @Cron 5분 재처리 (정본: §18 WebhookDLQ)
- **incident-log 박제 의무**: race condition 시도 차단 시 logger.warn `[PaymentRaceCondition] ...` 동반 (sensor-adversarial-pre-commit P20 정합)
- **DB schema 변경 0건**: advisory_lock + partial unique index는 P2 보류 (replicas ≥2 시점)

### 검증 게이트

- jest server: `payment.usecase.spec.ts` PAY-P3-A describe (4 it) + `prisma-payment.repository.spec.ts` PAY-P3-A describe (5 it)
- sensor: `sensor-payment-race-condition.sh` (8 검증)
- eval: `regression-66-payment-race-condition.json`

### 변경 시 동시 갱신 대상

- `grimoire-server/src/application/payment/payment.usecase.ts` (사전 게이트)
- `grimoire-server/src/application/payment/payment.usecase.spec.ts` (PAY-P3-A describe — 4 it: AC-1, AC-2, AC-3 시뮬, AC-6)
- `grimoire-server/src/application/payment/refund-payment.usecase.ts` (호출자 정합)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (CAS 패턴)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.spec.ts` (PAY-P3-A CAS describe — 5 it)
- `eval/tasks/regression-66-payment-race-condition.json`
- `.claude/scripts/sensor-payment-race-condition.sh`
- `reports/sprint-pay-p3-a-race-condition-progress.md` (Generator 진입 후 박제)

### 변경 이력
- 2026-05-09 #10_8 PAY-P3-A: 신설 — PAYMENT_AUDIT §1 구멍-A + 구멍-B 동시 차단. payment.status 사전 게이트 (refunded + partial_refunded) + refundPaymentAtomically CAS 패턴 (`findUniqueOrThrow + updateMany WHERE credits >= actualDeducted`). DB schema 변경 0건. PAY-P2-2 DLQ retry 패턴 정합. jest server 625 → 634 (+9 it). sensor 39 → 40 신설. eval regression 65 → 66 신설. 정본: `reports/sprint-pay-p3-a-race-condition-progress.md`.

---

## 23. RetryDeduplication (server 도메인 — webhook-retry.job 사전 dedup 게이트)

**위치**:
- Job: `grimoire-server/src/application/payment/webhook-retry.job.ts` (`retryDueWebhooks` for-loop 진입 직전 + `applyDedupGate` 헬퍼)
- Port: `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (`findByExternalTransactionId` 시그니처 — 기존 보존, 시그니처 변경 0건)
- Sensor: `.claude/scripts/sensor-retry-dedup.sh` (8 검증)

**적용**: PAYMENT_AUDIT §1 모순-D (WebhookRetryJob 5분 cron ↔ PaymentReconciliationJob 10분 cron 커버리지 겹침) 차단. S1 boost 또는 별도 cron으로 status가 이미 종료된 payment의 retry 진입 자체를 차단 — `processNormalizedWebhook` 호출 0건 + queue row 즉시 deleteById + AuditLog `retry_skip_dedup` 박제. DB schema 변경 0건. 외부 인프라 의존 0건. PAY-P3-A 사전 게이트와 이중 방어 정합 (retry 진입 차단 → payment.usecase 사전 게이트 호출 0건).

### 시그니처 — 사전 dedup 게이트

```typescript
// webhook-retry.job.ts retryDueWebhooks for-loop 진입 직전 (각 due item 처리 시작점)
for (const item of due) {
  const event = item.payload as NormalizedWebhookEvent

  // PAY-P3-C 모순-D 차단: payment.status 사전 dedup 게이트
  // (S1 boost 후 또는 별도 cron으로 status가 이미 완료/환불된 payment의 retry 시도 차단)
  // 정본: shared-contracts §23 RetryDeduplication
  const dedupResult = await this.applyDedupGate(item.id, item.eventId, item.retryCount, event)
  if (dedupResult.skipped) {
    skipDedupCount += 1
    continue
  }

  // 기존 흐름 — pending/failed/expired 상태일 때만 processNormalizedWebhook 호출
  try {
    await this.paymentUseCase.processNormalizedWebhook(event)
    await this.retryQueueRepo.deleteById(item.id)
    succeededCount += 1
    // ...
  } catch (e) {
    // 기존 markRetry / markPermanentFailed 흐름 보존
    // ...
  }
}
```

### 시그니처 — applyDedupGate 헬퍼

```typescript
private static readonly DEDUP_ACTION = 'retry_skip_dedup'
private static readonly FINALIZED_STATUSES = new Set([
  'completed',
  'refunded',
  'partial_refunded',
])

private async applyDedupGate(
  queueId: string,
  eventId: string,
  retryCount: number,
  event: NormalizedWebhookEvent,
): Promise<{ skipped: boolean }> {
  let payment
  try {
    payment = await this.paymentRepo.findByExternalTransactionId(event.tradeNo)
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e)
    this.logger.warn(
      `[retry] eventId=${eventId} retryCount=${retryCount} → dedup 게이트 조회 실패 (${msg.slice(0, 100)}) — 기존 흐름 유지`,
    )
    return { skipped: false }
  }

  if (!payment) return { skipped: false }
  if (!WebhookRetryJob.FINALIZED_STATUSES.has(payment.status)) return { skipped: false }

  // 사전 dedup 차단 발동 — queue row 즉시 삭제 + AuditLog 박제
  await this.retryQueueRepo.deleteById(queueId)

  try {
    await this.auditLog.log(
      WebhookRetryJob.DLQ_OPERATOR,
      WebhookRetryJob.DEDUP_ACTION,
      eventId,
      {
        reason: 'payment_already_finalized',
        paymentStatus: payment.status,
        retryCount,
        paymentId: payment.id,
      },
    )
  } catch (e: unknown) {
    // AuditLog 박제 실패는 트랜잭션 진행을 막지 않음 (logger.warn 박제 후 skipped=true 보존)
    const msg = e instanceof Error ? e.message : String(e)
    this.logger.warn(
      `AuditLog ${WebhookRetryJob.DEDUP_ACTION} 박제 실패 (eventId=${eventId}): ${msg}`,
    )
  }

  this.logger.log(
    `[retry] eventId=${eventId} retryCount=${retryCount} → SKIP_DEDUP (payment.status=${payment.status})`,
  )
  return { skipped: true }
}
```

### DI 주입 변경 (`webhook-retry.job.ts` constructor)

```typescript
constructor(
  @Inject('WebhookRetryQueueRepositoryPort')
  private readonly retryQueueRepo: WebhookRetryQueueRepositoryPort,
  @Inject('WebhookEventRepositoryPort')
  private readonly webhookEventRepo: WebhookEventRepositoryPort,
  // PAY-P3-C 신설 — 사전 dedup 게이트용 PaymentRepositoryPort 주입
  @Inject('PaymentRepositoryPort')
  private readonly paymentRepo: PaymentRepositoryPort,
  private readonly paymentUseCase: PaymentUseCase,
  private readonly auditLog: AuditLogService,
) {}
```

### logger.log 통계 박제 변경

기존:
```typescript
this.logger.log(
  `WebhookRetryJob 완료 — due=${due.length} success=${succeededCount} retry=${retryCount} permanent=${permanentFailedCount}`,
)
```

변경 후:
```typescript
this.logger.log(
  `WebhookRetryJob 완료 — due=${due.length} success=${succeededCount} retry=${retryCount} permanent=${permanentFailedCount} dedup=${skipDedupCount}`,
)
```

### 정책

- **사전 dedup 게이트 발동**: payment.status ∈ {'completed', 'refunded', 'partial_refunded'} → 즉시 deleteById + AuditLog `retry_skip_dedup`
- **payment.status='pending' 상태**: 기존 흐름 유지 (`processNormalizedWebhook` 호출)
- **payment 미존재 (findByExternalTransactionId null)**: 기존 흐름 유지 (`processNormalizedWebhook` 호출 → 내부에서 `unknown_trade` 게이트 발동)
- **payment.status='failed' OR 'expired'**: 기존 흐름 유지 (이 시나리오는 retry 의미 X 영역, 별도 sprint에서 결정 — PAY-P3-D status enum 또는 PAY-P2-5 retention)
- **AuditLog action 식별자**: `retry_skip_dedup` (operator='system_dlq', resourceId=eventId, meta: {reason, paymentStatus, retryCount, paymentId})
- **paymentRepo 조회 실패 시**: logger.warn 박제 + 기존 흐름 유지 (false negative 회피 — 조회 실패가 retry 차단으로 이어지지 않도록 보호)
- **AuditLog 박제 실패 시**: logger.warn 박제 + skipped=true 보존 (queue row 삭제는 이미 commit, AuditLog noise만 있으면 운영자 추적 가능)
- **incident-log 박제 의무**: dedup 차단 시 logger.log 동반 (sensor-adversarial-pre-commit P20)
- **DB schema 변경 0건**: 본 sprint = 의존성 1건 추가 (PaymentRepositoryPort) + 로직 1건 추가만
- **PAY-P3-A 정합 (이중 방어)**: PAY-P3-A는 `processNormalizedWebhook` 내부 사전 게이트 (line 187-204) — 본 sprint는 retry 진입 자체를 차단 → payment.usecase 사전 게이트는 0건 호출 → 이중 방어 정합

### 검증 게이트

- jest server: `webhook-retry.job.spec.ts` PAY-P3-C describe (6 it: AC-1, AC-2, AC-3, AC-4, AC-6, AC-7)
- sensor: `sensor-retry-dedup.sh` (8 검증)
- eval: `regression-67-retry-dedup.json`

### 변경 시 동시 갱신 대상

- `grimoire-server/src/application/payment/webhook-retry.job.ts` (DI + 사전 게이트 + 통계)
- `grimoire-server/src/application/payment/webhook-retry.job.spec.ts` (PAY-P3-C describe — 6 it)
- `grimoire-server/src/app.module.ts` (PaymentRepositoryPort 주입 정합 검증 — 기존 박제됨, WebhookRetryJob provider 영역만 정합 검증)
- `eval/tasks/regression-67-retry-dedup.json`
- `.claude/scripts/sensor-retry-dedup.sh`
- `reports/sprint-pay-p3-c-retry-dedup-progress.md` (Generator 진입 후 박제)

### 변경 이력
- 2026-05-09 #10_8 PAY-P3-C: 신설 — PAYMENT_AUDIT §1 모순-D (WebhookRetryJob ↔ ReconciliationJob 커버리지 겹침) 차단. webhook-retry.job 사전 dedup 게이트 (PaymentRepositoryPort 주입 + payment.status='completed'/'refunded'/'partial_refunded' 체크 + AuditLog `retry_skip_dedup` + skipDedupCount 통계). DB schema 변경 0건. PAY-P3-A 정합 (이중 방어). jest server 634 → 640 (+6 it). sensor 40 → 41 신설. eval regression 66 → 67 신설. 정본: `reports/sprint-pay-p3-c-retry-dedup-progress.md`.

---

## 24. PolarSDKTimeoutPolicy (server 도메인 — Polar SDK timeout 명시 + exception 분기)

**위치**:
- Adapter: `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` (`new Polar({ timeoutMs })` + `classifyPolarError` + catch 분류 적용)
- UseCase: `grimoire-server/src/application/payment/payment.usecase.ts` (`processNormalizedWebhook` success/cancel 분기 catch + `classifyAndRouteWebhookError` helper)
- Port: `grimoire-server/src/domain/port/outbound/payment-gateway.port.ts` (`PolarErrorClass` + `PolarErrorClassification` + `classifyPolarError?` Optional 메서드)
- Sensor: `.claude/scripts/sensor-polar-timeout-policy.sh` (5 검증)
- Env: `POLAR_SDK_TIMEOUT_MS` (기본값 30000, dev/prod 동일)
- Eval: `eval/tasks/regression-68-polar-timeout.json` (8 checks)

**적용**: PAYMENT_AUDIT §1 구멍-C (Polar SDK exception type 미매핑 + timeout 정책 미명시) 차단. DB schema 변경 0건. 외부 API 추가 호출 0건 (기존 SDK 옵션만 변경). PAY-P2-2 DLQ retry 정합 (timeout/network/5xx만 retry, 4xx 즉시 permanent_failed).

### 시그니처 — Polar SDK timeout 옵션 (옵션 A 채택)

```typescript
// polar.adapter.ts constructor
constructor() {
  const accessToken = process.env.POLAR_ACCESS_TOKEN ?? ''
  const server = (process.env.POLAR_SERVER ?? 'production') as 'sandbox' | 'production'
  this.webhookSecret = process.env.POLAR_WEBHOOK_SECRET ?? ''

  // PAY-P3-B: 옵션 A 채택 — Polar SDK v0.47.0 SDKOptions.timeoutMs 내장 옵션 사용
  // (config.d.ts L38 검증 — "timeoutMs?: number" 직접 지원).
  // env POLAR_SDK_TIMEOUT_MS 미설정 시 기본 30s. parseInt 실패 시(NaN) 30s fallback.
  const parsed = parseInt(process.env.POLAR_SDK_TIMEOUT_MS ?? '', 10)
  this.timeoutMs = Number.isFinite(parsed) && parsed > 0 ? parsed : 30000

  this.polar = new Polar({
    accessToken,
    server,
    timeoutMs: this.timeoutMs,
  })
}
```

### 시그니처 — PolarErrorClassification (도메인 포트 정본)

```typescript
// payment-gateway.port.ts
export type PolarErrorClass =
  | 'timeout'      // AbortError, TimeoutError, RequestTimeoutError, RequestAbortedError, message 'timeout'
  | 'network'      // ECONNRESET, ENOTFOUND, ETIMEDOUT, EPIPE, ECONNREFUSED, ConnectionError
  | 'server_5xx'   // HTTP 500/502/503/504 등 (PolarError.statusCode 추출)
  | 'client_4xx'   // HTTP 400/401/403/404/422 등 (retry 무의미 → permanent_failed)
  | 'unknown'      // 분류 실패 시 안전 측면 fallback (retry 가능 영역)

export interface PolarErrorClassification {
  errorClass: PolarErrorClass
  httpStatus?: number  // server_5xx / client_4xx 분류 시 필수
  message: string      // 원본 에러 메시지 (500자 이내 truncate 권장)
}

export interface PaymentGatewayPort {
  initiatePayment(...): Promise<PaymentInitResponse>
  verifyAndParseWebhook(...): NormalizedWebhookEvent | null
  listRecentCheckouts(...): Promise<NormalizedCheckout[]>
  /** PAY-P3-B Optional 메서드 — 미구현 adapter는 'unknown' fallback (회귀 보존) */
  classifyPolarError?(e: unknown): PolarErrorClassification
}
```

### 시그니처 — classifyPolarError helper (PolarAdapter 구현)

```typescript
// polar.adapter.ts — public method (port 인터페이스 정합 + duck typing)
classifyPolarError(e: unknown): PolarErrorClassification {
  const message = e instanceof Error ? e.message : String(e)
  const errorName = e instanceof Error ? e.name : ''

  // 1. timeout 분류 (AbortError, TimeoutError, RequestTimeoutError, RequestAbortedError, /timeout/i, /aborted?/i)
  if (errorName === 'AbortError' || errorName === 'TimeoutError' ||
      errorName === 'RequestTimeoutError' || errorName === 'RequestAbortedError' ||
      /\btimeout\b/i.test(message) || /\baborted?\b/i.test(message)) {
    return { errorClass: 'timeout', message }
  }

  // 2. network 분류 (ConnectionError + Node.js system error prefixes)
  if (errorName === 'ConnectionError' ||
      /^(ECONNRESET|ENOTFOUND|ETIMEDOUT|EPIPE|ECONNREFUSED)/.test(message) ||
      /\b(ECONNRESET|ENOTFOUND|ETIMEDOUT|EPIPE|ECONNREFUSED)\b/.test(message)) {
    return { errorClass: 'network', message }
  }

  // 3. HTTP 응답 분류 — duck typing (PolarError.statusCode + legacy fetch + axios-like)
  const httpStatus = this.extractHttpStatus(e)
  if (httpStatus !== undefined) {
    if (httpStatus >= 500 && httpStatus < 600) return { errorClass: 'server_5xx', httpStatus, message }
    if (httpStatus >= 400 && httpStatus < 500) return { errorClass: 'client_4xx', httpStatus, message }
  }

  // 4. fallback (retry 가능 영역)
  return { errorClass: 'unknown', message }
}
```

### 시그니처 — payment.usecase 분기 처리 (classifyAndRouteWebhookError)

```typescript
// payment.usecase.ts — private helper
private async classifyAndRouteWebhookError(
  e: unknown,
  event: NormalizedWebhookEvent,
  paymentId: string,
  branch: 'success' | 'cancel',
): Promise<PolarErrorClassification> {
  const polarError = this.paymentGateway.classifyPolarError?.(e) ??
    { errorClass: 'unknown', message: e instanceof Error ? e.message : String(e) }

  if (polarError.errorClass === 'client_4xx') {
    // 4xx — retry 무의미, 즉시 permanent_failed 박제
    this.logger.error(`[PolarSDK] client_4xx eventId=${event.eventId} branch=${branch} httpStatus=${polarError.httpStatus} → permanent_failed (retry 0건)`)
    if (this.auditLog) {
      await this.auditLog.log('system_dlq', 'webhook_permanent_failed', event.eventId, {
        reason: 'polar_4xx_no_retry',
        errorClass: polarError.errorClass,
        httpStatus: polarError.httpStatus,
        paymentId,
        branch,
        originalMessage: polarError.message.slice(0, 500),
      })
    }
    await this.enqueueWebhookRetry(event as object, event.eventId, 'permanent_failed')
  } else {
    // timeout / network / server_5xx / unknown — retry 의미 있음
    this.logger.warn(`[PolarSDK] ${polarError.errorClass} eventId=${event.eventId} branch=${branch} → retry`)
    await this.enqueueWebhookRetry(event as object, event.eventId, 'retry')
  }
  return polarError
}
```

### 정책

- **5분류 매트릭스**:
  - `timeout` → retry (AbortError, TimeoutError, message에 'timeout'/'aborted' 포함)
  - `network` → retry (ECONNRESET, ENOTFOUND, ETIMEDOUT, EPIPE, ECONNREFUSED, ConnectionError)
  - `server_5xx` → retry (HTTP 500/502/503/504 등)
  - `client_4xx` → **permanent_failed 즉시 박제** (HTTP 400/401/403/404/422 등 — retry 무의미)
  - `unknown` → retry (안전 측면 — 분류 실패 시 retry 가능 영역으로 fallback)
- **timeout 정책**: SDK 호출별 30초 (env `POLAR_SDK_TIMEOUT_MS` 오버라이드). dev/prod 동일.
- **AuditLog 식별자**: 4xx 즉시 permanent → `operator='system_dlq' action='webhook_permanent_failed'` (기존 PAY-P2-2 MAX_RETRY 누적 후 동일 action 박제와 정합).
- **PAY-P2-2 DLQ 정합**: timeout/network/5xx → 기존 enqueueWebhookRetry 흐름 보존 (회귀 0). 4xx만 retry queue 박제 0건 (`enqueueWebhookRetry(event, eventId, 'permanent_failed')` 명시).
- **PAY-P3-A 정합 (영역 분리)**: PAY-P3-A는 webhook 사전 게이트 (refunded 상태 차단), 본 sprint는 catch 분기 처리 — 영역 분리 (정합 회귀 0).
- **PAY-P3-C 정합 (영역 분리)**: PAY-P3-C는 webhook-retry.job 사전 dedup, 본 sprint는 catch 분기 처리 — 영역 분리 (정합 회귀 0).
- **DB schema 변경 0건**: 본 sprint = SDK 옵션 + helper + catch 분기만.

### PaymentGatewayPort 시그니처 변경 영역 (옵션 B 채택)

- **옵션 B 채택**: `PaymentGatewayPort.classifyPolarError?` Optional 메서드 (회귀 0 보장)
- 다른 adapter (예: 향후 PayApp) 미구현 영역 정합 (Optional → 호출자가 'unknown' fallback)
- 옵션 A (PolarAdapter private 메서드만) 보류 사유: usecase가 직접 폴리모픽 호출 불가
- 옵션 C (별도 PaymentErrorClassifierPort 신설) 보류 사유: ~2h 초과 영역

### 검증 게이트

- jest server: `polar.adapter.spec.ts` PAY-P3-B describe (≥ 4 it) + `payment.usecase.spec.ts` (≥ 2 it)
- sensor: `sensor-polar-timeout-policy.sh` (5 검증)
- eval: `regression-68-polar-timeout.json` (8 checks)

### 변경 시 동시 갱신 대상

- `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` (timeout 옵션 + classifyPolarError + catch 분류)
- `grimoire-server/src/adapter/outbound/payment/polar.adapter.spec.ts` (≥ 4 it)
- `grimoire-server/src/application/payment/payment.usecase.ts` (catch 분기 처리)
- `grimoire-server/src/application/payment/payment.usecase.spec.ts` (≥ 2 it)
- `grimoire-server/src/domain/port/outbound/payment-gateway.port.ts` (`PolarErrorClass` + `PolarErrorClassification` + `classifyPolarError?` Optional)
- `grimoire-server/docs/api-contract.md` (webhook 처리 상태 표 webhook_permanent_failed_4xx 박제)
- `grimoire-server/docs/data-model.md` (AuditLog action 표 — webhook_permanent_failed 추가)
- `grimoire-server/docs/environments.md` (POLAR_SDK_TIMEOUT_MS env 추가)
- `grimoire-server/SECURITY.md §3` (결제 원자성 영역 본 sprint timeout 정책 박제)
- `grimoire-server/ADR.md` (Polar SDK timeout 결정 박제 — 옵션 A 채택 사유)
- `eval/tasks/regression-68-polar-timeout.json`
- `.claude/scripts/sensor-polar-timeout-policy.sh`
- `reports/sprint-pay-p3-b-polar-timeout-progress.md` (Generator 산출 정본)

### 변경 이력
- 2026-05-09 #10_8 PAY-P3-B: 신설 — PAYMENT_AUDIT §1 구멍-C (Polar SDK exception type 미매핑 + timeout 정책 미명시) 차단. polar.adapter `new Polar({ timeoutMs })` 옵션 A 채택 (Polar SDK v0.47.0 SDKOptions.timeoutMs 내장 옵션 직접 지원, config.d.ts L38 검증) + `classifyPolarError` public method (5분류 timeout/network/server_5xx/client_4xx/unknown, duck typing) + payment.usecase `classifyAndRouteWebhookError` private helper (success/cancel 분기 catch에서 호출, 4xx → permanent_failed 즉시 박제 + AuditLog `webhook_permanent_failed`, 외 4분류 → retry queue 박제). PaymentGatewayPort `classifyPolarError?` Optional 메서드 추가 (옵션 B 채택, 회귀 0 보장). DB schema 변경 0건. PAY-P2-2 DLQ 정합 (timeout/network/5xx만 retry). 정본: `reports/sprint-pay-p3-b-polar-timeout-progress.md`.

---

## 25. FKCascadePolicy (server 도메인 — PAY-P3-E 모순-F 차단, 33 FK 영역 onDelete 정책)

### 위치
- Schema: `grimoire-server/prisma/schema.prisma` (33 FK 영역 onDelete directive 명시 + 25 raw FK @relation 박제)
- Migration: `grimoire-server/prisma/migrations/20260510_pay_p3_e_fk_cascade_policy/migration.sql` (ALTER TABLE 33 + DROP NOT NULL 2 영역)
- Spec: `grimoire-server/src/adapter/outbound/persistence/prisma-fk-cascade.spec.ts` (8 it 박제)
- ADR: `grimoire-server/ADR.md ADR-007` (4 전략 결정 사유)
- Sprint Initializer: `.claude/state/sprint-pay-p3-e-fk-cascade-draft.md` (1233 lines, 13 섹션)
- 단계 1 raw: `.claude/state/pay-p3-e-fk-measure-raw.md` (33 FK 측정)
- 단계 2 raw: `.claude/state/pay-p3-e-fk-backfill-raw.md` (옵션 C archive 강제 박제 + 시나리오 A 회복)
- 단계 3 진입 audit: `.claude/state/pay-p3-e-pre-migration-audit-draft.md` (PASS)
- 단계 3+4 raw: `.claude/state/pay-p3-e-dev-migration-raw.md` (본 작업 영역)

### 적용
PAYMENT_AUDIT §1 모순-F (FK cascade 미정의 — Author 삭제 시 22 테이블 고아 행 위험) 차단. EMAIL-P0-2 백필 영역 정합 (UPDATE 전략 vs DELETE 전략 결정 영역). DB schema 변경 1건 (마이그레이션 1건). 외부 API 추가 호출 0건.

### 4 전략 매트릭스 (33 FK 정합)

#### Cascade 16건 (사용자 종속 + Work/Episode 종속 + 통계)

`refresh_tokens.authorId` / `chat_sessions.authorId` / `chat_sessions.workId` / `bookmarks.authorId` / `bookmarks.episodeId` / `reading_progress.authorId` / `reading_progress.episodeId` / `social_accounts.authorId` / `subscriptions.subscriberId` / `subscriptions.targetAuthorId` / `daily_views.workId` / `featured_works.workId` / `comments.episodeId` / `likes.episodeId` / `episodes.workId` / `chat_messages.sessionId` (이미 박제, 변경 0)

#### Restrict 8건 (회계/세무/감사 영구 보존, **Author hard delete 차단 강제**)

`payments.authorId` / `credit_logs.authorId` / `works.authorId` / `user_sanctions.authorId` / `analysis_reports.authorId` / `admin_audit_logs.adminId` / `refund_logs.paymentId`

**핵심 사용자 결정 A 정합 (5/9 박제)**: Author hard delete 자체 차단 영역 = USER-SOFT-DELETE sprint 영역 분리 (본 sprint = FK 제약만 + 회계 8건 Restrict).

#### SetNull 9건 (익명화 + 운영자 변경 보존 + 기본값 유지)

`themes.authorId` / `works.themeId` / `likes.authorId` / `comments.authorId` / `comments.parentId` / `reports.reporterId` / `reports.resolvedBy` / `access_logs.authorId` / `featured_works.adminId` / `user_sanctions.adminId`

#### NoAction 0건 (PG default와 동일, 명시 0건)

### 시그니처 — Prisma schema onDelete directive

```prisma
// 예: payments.authorId Restrict 박제 (회계 영구 보존)
model Payment {
  authorId String @map("author_id")
  author   Author @relation(fields: [authorId], references: [id], onDelete: Restrict)
}

// 예: episodes.workId Cascade 박제 (Work 삭제 시 episode 자동 삭제)
model Episode {
  workId String @map("work_id")
  work   Work   @relation(fields: [workId], references: [id], onDelete: Cascade)
}

// 예: comments.authorId SetNull 박제 (익명화)
model Comment {
  authorId String? @map("author_id")
  author   Author? @relation(fields: [authorId], references: [id], onDelete: SetNull)
}

// self-ref @relation name 영역 (다중 FK 충돌 차단)
model Subscription {
  subscriberId   String @map("subscriber_id")
  subscriber     Author @relation("Subscriber",   fields: [subscriberId],   references: [id], onDelete: Cascade)
  targetAuthorId String @map("target_author_id")
  targetAuthor   Author @relation("TargetAuthor", fields: [targetAuthorId], references: [id], onDelete: Cascade)
}
```

### 시그니처 — migration SQL 영역 (ALTER TABLE 33 + DROP NOT NULL 2)

```sql
-- (a) Optional 변경 영역 (FeaturedWork.adminId / UserSanction.adminId Required → Optional)
ALTER TABLE "featured_works" ALTER COLUMN "admin_id" DROP NOT NULL;
ALTER TABLE "user_sanctions" ALTER COLUMN "admin_id" DROP NOT NULL;

-- (b) 6 박제 영역 onDelete directive 영역 (DROP + ADD CONSTRAINT)
ALTER TABLE "themes" DROP CONSTRAINT "themes_author_id_fkey";
ALTER TABLE "themes" ADD CONSTRAINT "themes_author_id_fkey"
  FOREIGN KEY ("author_id") REFERENCES "authors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
-- ... (5 추가 영역)

-- (c) 25 raw FK 영역 ADD CONSTRAINT 영역
ALTER TABLE "credit_logs" ADD CONSTRAINT "credit_logs_author_id_fkey"
  FOREIGN KEY ("author_id") REFERENCES "authors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- ... (24 추가 영역)
```

### 단계 1+2 raw 박제 영역 정합

**단계 1 (33 FK 측정, 2026-05-10)**:
- 31 / 33 = 시나리오 A (orphan=0)
- 2 / 33 = 시나리오 B (`credit_logs.author_id` 1 + `admin_audit_logs.admin_id` 2)

**단계 2 (옵션 C archive 강제, 2026-05-10)**:
- archive 테이블 신설 (LIKE INCLUDING ALL clone): `credit_logs_archive_pay_p3_e` + `admin_audit_logs_archive_pay_p3_e`
- INSERT 3 row → DELETE 3 row → 33/33 시나리오 A 회복 강제
- 회계/감사 영구 보존 정합 (옵션 B 직접 삭제 절대 금지 영역)

### 회귀 차단 정합

- jest server 661 → **669 PASS** (+8 it 신설, `prisma-fk-cascade.spec.ts`)
- shared-contracts §1~24 → **§1~25** (본 §25 신설)
- 기존 12 sprint (PAY-P0-1/0-2/0-3/P1-1/P1-3/P2-1/P2-2/P2-3/P2-4/P3-A/P3-B/P3-C) + EMAIL-P0-2 회귀 0건 정합

### 변경 이력
- 2026-05-10 #10_8 PAY-P3-E: 신설 — PAYMENT_AUDIT §1 모순-F (FK cascade 미정의 — Author 삭제 시 22 테이블 고아 행 위험) 차단. 33 FK 영역 onDelete directive 명시 (Cascade 16 + Restrict 8 + SetNull 9). 25 raw FK 영역 @relation directive 신설. 마이그레이션 SQL 신설 (ALTER TABLE 33 + DROP NOT NULL 2). 8 it 신설 spec 박제. dev 영역 단계 1+2 사용자 결정 A 정합 (회계 8건 Restrict 강제) — credit_logs 1 + admin_audit_logs 2 archive 영구 보존 + 33/33 시나리오 A 회복. USER-SOFT-DELETE sprint 영역 분리 정합 박제. 정본: `prisma/schema.prisma` + `prisma/migrations/20260510_pay_p3_e_fk_cascade_policy/migration.sql` + `ADR.md ADR-007`.

---

## 26. AuditRetentionPolicy (server 도메인 — PAY-P2-5 audit 영구 보존 + 90일 PII 마스킹)

### 위치
- helper: `grimoire-server/src/adapter/outbound/persistence/audit-mask-helper.ts`
- scheduler: `grimoire-server/src/application/admin/audit-mask.job.ts`
- migration: `grimoire-server/prisma/migrations/20260510_pay_p2_5_audit_retention_policy/migration.sql`
- ADR: `grimoire-server/ADR.md ADR-008`

### 사용자 결정 박제 (5/10 verbatim "d로 하고")
- **영구 보존**: DELETE 0건 강제 (audit gap 0)
- **90일 후 PII 마스킹**: 매일 03:00 KST cron
- **PII 7 키 자동 검출**: email / phone / ipAddress / userAgent / passwordHash / token / secret
- **보존 키 매트릭스**: id / userId / authorId / adminId / action / createdAt / amount / credits 등 audit 본질 보존

### 4 모델 컬럼 매트릭스

| 모델 | 신설 컬럼 | 마스킹 영역 (90일 후) | 영구 보존 영역 |
|---|---|---|---|
| AdminAuditLog | `maskedAt DateTime?` + `retentionTier String @default("active")` | detail JSON deep masking | id/adminId/action/targetId/createdAt 보존 |
| WebhookEvent | 동일 | payload JSON deep masking + errorMessage='***' | id/eventId/source/eventType/status/processedAt 보존 |
| WebhookRetryQueue | 동일 | payload JSON deep masking + lastError='***' | id/eventId/retryCount/nextRetryAt/createdAt 보존 |
| AccessLog | 동일 | email/ip/userAgent (detail string 자유 형식 보존) | id/action/authorId/createdAt 보존 |

### PII 마스킹 패턴

| PII 키 | 마스킹 패턴 | 예시 |
|---|---|---|
| email | `<first>***@<domain>` | `john@example.com` → `j***@example.com` |
| phone | `010-****-****` | `010-1234-5678` → `010-****-****` |
| ipAddress | `<a>.<b>.***.**` | `192.168.1.100` → `192.168.***.**` |
| userAgent | `<browser> (***)` | 전체 UA → `Mozilla/5.0 (***)` |
| passwordHash / token / secret | `***` | 전체 → `***` |

### 시그니처 (TypeScript)

```typescript
export interface AuditRetentionPolicy {
  /** 4 모델 마스킹 1회 수행. 직접 호출 가능 (단계 7 dev cron 직접 호출 검증용). */
  runMaskingPass(cutoff: Date): Promise<MaskingResult>;
}

export interface MaskingResult {
  modelsProcessed: string[];
  rowsMasked: number;
  rowsSkipped: number;
  errors: { rowId: string; error: string }[];
}
```

### 멱등성 강제

- `WHERE retentionTier='active' AND created_at < cutoff` 검색만 → 재마스킹 0건
- 마스킹 성공 시 `retentionTier='masked'` + `maskedAt=NOW()` 갱신
- 다음 cron에서 동일 row 재선택 0건

### 비활성화 게이트

- `process.env.AUDIT_MASK_DISABLED === '1'` 즉시 return (운영자 수동 차단용)

### 회귀 차단 정합

- jest server `audit-mask-helper.spec.ts` (≥18 it: PII_KEYS 1 + PRESERVED_KEYS 2 + maskEmail 4 + maskPhone 4 + maskIpAddress 3 + maskUserAgent 2 + maskSecret 1 + maskValueByKey 12 + maskJsonDeep 5 + maskAccessLogRow 2)
- jest server `audit-mask.job.spec.ts` (≥6 it: 시나리오 A noop + AdminAuditLog detail + AccessLog 4 컬럼 + 멱등성 WHERE + 단일 row 실패 + 비활성화 게이트)
- `eval/tasks/regression-70-audit-retention-policy.json` (11 criteria)
- `sensor-audit-retention-policy.sh` (12 검증)

### 변경 이력
- 2026-05-10 #10_8 PAY-P2-5: 신설 — audit retention 정책 미정의 (PAYMENT_AUDIT §3 L84-85) 차단. 사용자 결정 옵션 D (영구 보존 + 90일 후 PII 마스킹). 4 모델 (admin_audit_logs / webhook_events / webhook_retry_queues / access_logs) `maskedAt DateTime?` + `retentionTier String @default("active")` 컬럼 추가. PII 7 키 자동 검출 helper + JSON deep masking + AccessLog 4 컬럼 마스킹. @Cron('0 0 3 * * *') 매일 03:00 KST scheduler. dev 측정 결과 (5/10): 22 row / 90일 경과 0건 (시나리오 A 정합). 정본: `migration.sql` + `audit-mask-helper.ts` + `audit-mask.job.ts` + `ADR.md ADR-008`.

---

## 27. CircuitBreakerPolicy (server 도메인 — Polar SDK 호출 경계 가용성 차단)

### 위치
- model: `grimoire-server/src/domain/model/circuit-breaker-state.ts` (3 상태 enum + Policy + Stats + CircuitOpenError)
- port: `grimoire-server/src/domain/port/outbound/circuit-breaker.port.ts` (CircuitBreakerPort 인터페이스 정본)
- adapter: `grimoire-server/src/adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.ts` (Map 기반 구현)
- spec: `grimoire-server/src/adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.spec.ts` (18 it)
- 적용: `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` (2 호출점 래핑: checkouts.create / checkouts.list)
- 호출자 분기: `grimoire-server/src/application/payment/payment.usecase.ts` (CircuitOpenError → ServiceUnavailableException), `grimoire-server/src/application/payment/payment-reconciliation.job.ts` (cron skip)
- DI: `grimoire-server/src/app.module.ts` (`'CircuitBreakerPort' → InMemoryCircuitBreakerAdapter`)
- ADR: `grimoire-server/ADR.md ADR-009`
- sensor: `.claude/scripts/sensor-circuit-breaker-policy.sh` (10 검증)
- eval: `eval/tasks/regression-71-circuit-breaker-policy.json` (12 criteria)
- env 4건: `POLAR_CB_FAILURE_THRESHOLD` (기본 5) / `POLAR_CB_COOLDOWN_MS` (기본 30_000) / `POLAR_CB_HALF_OPEN_TRIAL` (기본 3) / `POLAR_CB_RESET_WINDOW_MS` (기본 60_000)

### 시그니처

```typescript
// circuit-breaker-state.ts
export enum CircuitBreakerState {
  CLOSED = 'closed',      // 정상 흐름 (모든 호출 통과)
  OPEN = 'open',          // 차단 (모든 호출 즉시 fail-fast)
  HALF_OPEN = 'half_open' // 회복 시도 (trial 횟수만큼 호출 허용)
}

export interface CircuitBreakerPolicy {
  failureThreshold: number   // 기본 5 (옵션 B Hystrix 정합)
  cooldownMs: number         // 기본 30_000
  halfOpenTrial: number      // 기본 3
  resetWindowMs: number      // 기본 60_000
}

export interface CircuitBreakerStats {
  state: CircuitBreakerState
  failureCount: number
  openedAt?: Date
  halfOpenAt?: Date
  halfOpenTrialCount: number
  halfOpenSuccessCount: number
  lastSuccessAt?: Date
  lastFailureAt?: Date
}

export class CircuitOpenError extends Error {
  constructor(
    public readonly circuitKey: string,
    public readonly stats: CircuitBreakerStats,
  ) {
    super(`Circuit breaker OPEN — ${circuitKey} (failureCount=${stats.failureCount})`)
    this.name = 'CircuitOpenError'
  }
}

// circuit-breaker.port.ts
export interface CircuitBreakerPort {
  execute<T>(key: string, fn: () => Promise<T>): Promise<T>
  getState(key: string): CircuitBreakerState
  getStats(key: string): CircuitBreakerStats
  forceOpen(key: string, reason: string): Promise<void>
  forceClose(key: string, reason: string): Promise<void>
}
```

### 정책 매트릭스 (사용자 5/15 결정 옵션 B Hystrix 정합)

| 임계값 | 값 | 영역 |
|---|---|---|
| failureThreshold | 5회 연속 실패 | CLOSED → OPEN 전환 |
| cooldownMs | 30_000 (30초) | OPEN 상태 지속 시간 |
| halfOpenTrial | 3회 | HALF_OPEN trial 허용 횟수 (모두 성공 시 CLOSED 복귀) |
| resetWindowMs | 60_000 (1분) | CLOSED 상태 failureCount 자연 리셋 윈도우 |

### 상태 전환 매트릭스

| 현재 상태 | 트리거 | 다음 상태 | 부작용 |
|---|---|---|---|
| CLOSED | 호출 성공 | CLOSED | lastSuccessAt 갱신 (failureCount 보존, reset window 정합) |
| CLOSED | 호출 실패 | CLOSED | failureCount++ (임계값 미달) |
| CLOSED | 실패 임계값 초과 | OPEN | openedAt=now, AuditLog `circuit_breaker.open` 박제 |
| CLOSED | reset window 경과 + failureCount > 0 | CLOSED | failureCount=0 (자연 리셋) |
| OPEN | 호출 요청 | OPEN | 즉시 CircuitOpenError throw + AuditLog `circuit_breaker.reject` 박제 |
| OPEN | cooldown 경과 + 호출 요청 | HALF_OPEN | halfOpenAt=now, AuditLog `circuit_breaker.half_open_trial` 박제 |
| HALF_OPEN | trial 호출 성공 | HALF_OPEN | halfOpenSuccessCount++ (trial 미달 시 유지) |
| HALF_OPEN | trial halfOpenTrial 도달 + 모두 성공 | CLOSED | failureCount=0, AuditLog `circuit_breaker.close` 박제 |
| HALF_OPEN | trial 호출 실패 | OPEN | openedAt=now (cooldown 재시작), AuditLog `circuit_breaker.open` 박제 |
| HALF_OPEN | 추가 호출 요청 (trial 초과) | HALF_OPEN | 즉시 CircuitOpenError throw + AuditLog `circuit_breaker.reject` 박제 |

### 호출점별 분리 매트릭스

| 호출점 키 | 현재 적용 | 적용 위치 |
|---|---|---|
| `polar:checkouts:create` | ✅ 적용 | `polar.adapter.ts` initiatePayment |
| `polar:checkouts:list` | ✅ 적용 | `polar.adapter.ts` listRecentCheckouts |
| `polar:checkouts:get` | 향후 (코드 미존재) | (향후 추가 시 자동 적용 영역) |

호출점별 독립 상태 — 한 호출점 OPEN 시 다른 호출점 영향 0 강제.

### AuditLog 4 action 박제 매트릭스

| action | 영역 | reason 매트릭스 |
|---|---|---|
| `circuit_breaker.open` | CLOSED→OPEN, HALF_OPEN→OPEN, forceOpen | `failure_threshold_exceeded` / `half_open_trial_failed` / `manual_force_open: <reason>` |
| `circuit_breaker.close` | HALF_OPEN→CLOSED, forceClose | `half_open_trial_succeeded` / `manual_force_close: <reason>` |
| `circuit_breaker.half_open_trial` | OPEN→HALF_OPEN | `cooldown_elapsed` |
| `circuit_breaker.reject` | OPEN 호출 차단, HALF_OPEN trial 초과 | `circuit_open` / `half_open_trial_exhausted` |

### 외부 의존 매트릭스 (사용자 5/10 정합 강제)

| 영역 | 추가 의존 | 정합 |
|---|---|---|
| 외부 API (Anthropic / Polar / SaaS) | **0건** | 사용자 절대 규정 0-1 정합 |
| 외부 npm 패키지 | **0건** | opossum / cockatiel 거부, 자체 구현 |
| DB schema 변경 | **0건** | 사용자 5/10 명시 정합, in-memory |
| dev migration | **0건** | 사용자 5/10 명시 정합 |
| 인프라 변경 (Azure Container Apps / replicas) | **0건** | 단일 인스턴스 가정 |
| Redis / 외부 인프라 | **0건** | in-memory 정합 |

### 정합 매트릭스 (다른 sprint 회귀 차단)

- §24 PolarSDKTimeoutPolicy 정합 — 4xx 분류 시 failureCount++ 영향 0 (요청 결함, SDK/Polar 장애 0)
- §23 RetryDeduplication 정합 — circuit breaker는 DLQ 진입 전 차단, DLQ 흐름 0 영향
- §22 PaymentRaceCondition 정합 — circuit breaker는 SDK 경계 영역, DB 트랜잭션 영역 0 영향
- §20 AuditLog beforeState/afterState Convention 정합 — `circuit_breaker.*` 4 action 박제 (detail JSON에 reason + circuitKey + 통계 박제)

### 잔존 영역

- 다중 인스턴스 환경 — in-memory 상태 분리 (Redis 별도 sprint)
- 정책 변경 시 Container Apps 재시작 필요 (in-memory 0 초기화)
- 관리자 UI (forceOpen/forceClose) — P3-I 별도 sprint 분리 (port 인터페이스만 본 sprint 박제)

### 변경 이력
- 2026-05-15 #10_8 PAY-P3-H: 신설 — Polar SDK 호출 경계 가용성 차단 (PAY-P3-B 후속). Hystrix 3 상태 머신 자체 구현 + 사용자 5/15 결정 옵션 B 정합 (failureThreshold=5/cooldownMs=30_000/halfOpenTrial=3/resetWindowMs=60_000). 2 호출점 박제 (checkouts.create + checkouts.list, checkouts.get는 향후). AuditLog 4 action 박제 (open/close/half_open_trial/reject). env 4건. CircuitOpenError 분기 (ServiceUnavailableException 변환 + cron skip). 외부 의존 0건 + DB schema 0건 + dev migration 0건 강제. jest 711 → 735 PASS (+24 it). 정본: `circuit-breaker-state.ts` + `circuit-breaker.port.ts` + `in-memory-circuit-breaker.adapter.ts` + `ADR.md ADR-009`.

---

## 28. PaymentStatusMapping (server 도메인 — PAY-P3-D Status enum + Polar 매핑 정책)

### 컨텍스트
- 결제 도메인 영역 status literal 영역 분산 (5 영역):
  - DB `payments.status` String (`pending` / `completed` / `failed` / `refunded` / `partial_refunded`)
  - DB `webhook_events.status` String (`processed` / `skipped` / `failed`)
  - Port `NormalizedWebhookEvent.status` literal (`success` / `fail` / `cancel`)
  - Port `NormalizedCheckout.status` literal (`succeeded` / `refunded` / `failed` / `open`)
  - DB `refund_logs.source` String (`webhook` / `manual`)
- 매핑 함수 영역 polar.adapter.ts private 메서드 2개 (`mapOrderStatus` + `mapCheckoutStatus`) → 도메인 영역 분리 X (헥사고날 DIP 결함 — 어휘 통일 부재)
- 사용자 5/15 결정 정합: schema 0 + dev migration 0 + 외부 API 0 강제
- 도입 목표: 어휘 통일 + 매핑 함수 도메인 model 이전 + race condition 통합 helper 박제 (`isPaymentAlreadyRefunded`)

### 결정
- **도메인 enum 5건 박제** (`src/domain/model/payment-status.ts`):
  - `PAYMENT_STATUS` (5 values): DB `payments.status` 어휘
  - `WEBHOOK_EVENT_STATUS` (3 values): DB `webhook_events.status` 어휘
  - `NORMALIZED_WEBHOOK_STATUS` (3 values): Port webhook 정규화 어휘
  - `NORMALIZED_CHECKOUT_STATUS` (4 values): Port checkout 정규화 어휘 (PAY-P0-2 reconciliation 정합)
  - `REFUND_SOURCE` (2 values): RefundLog source 어휘
- **매핑 함수 2건 도메인 model 박제**:
  - `mapPolarOrderStatus(status?: string): NormalizedWebhookStatus` — Polar order.status → 정규화 어휘
  - `mapPolarCheckoutStatus(status?: string): NormalizedCheckoutStatus` — Polar checkout.status → 정규화 어휘
- **helper 함수 3건 박제** (race condition 통합 + Polar status 판정):
  - `isPaymentAlreadyRefunded(status: string): boolean` — `payment.status === 'refunded' || === 'partial_refunded'` 통합 (§22 정합)
  - `isPolarRefundedStatus(status?: string): boolean` — Polar status='refunded' 판정
  - `isPolarSuccessStatus(status?: string): boolean` — Polar status='paid' || 'succeeded' 판정
- **호출자 통합 영역**:
  - `polar.adapter.ts`: private `mapOrderStatus` / `mapCheckoutStatus` 메서드 도메인 helper 위임 (호출 패턴 보존 X 호출 시그니처 유지)
  - `payment.usecase.ts`: `isPaymentAlreadyRefunded(payment.status)` 통합 + `event.status === NORMALIZED_WEBHOOK_STATUS.*` 어휘 통합 + `status: WEBHOOK_EVENT_STATUS.PROCESSED` 어휘 1회 통합 (이외 영역은 보존 — 회귀 최소화)
- **DB schema 변경 0건 강제**: Prisma `String` 컬럼 유지 (enum 변환 X, dev migration 0)
- **외부 npm 라이브러리 0건 + 외부 API 0건** 정합

### 매핑 매트릭스

#### Polar order.status → NormalizedWebhookStatus (mapPolarOrderStatus)
| Polar order.status | NormalizedWebhookStatus | 분기 |
|---|---|---|
| `paid` | `success` | order.paid webhook → completePaymentAtomically |
| `succeeded` | `success` | order.updated webhook → completePaymentAtomically |
| `refunded` | `cancel` | order.refunded webhook → refundPaymentAtomically |
| (그 외 / undefined) | `fail` | 안전 측면 fallback (pending/canceled/unknown) |

#### Polar checkout.status → NormalizedCheckoutStatus (mapPolarCheckoutStatus)
| Polar checkout.status | NormalizedCheckoutStatus | 분기 |
|---|---|---|
| `succeeded` | `succeeded` | S1 boost 후보 (reconciliation match) |
| `expired` | `failed` | 결제 결함 |
| `failed` | `failed` | 결제 결함 |
| `open` | `open` | 사용자 결제 진행 중 |
| `confirmed` | `open` | 결제 확인 단계 (webhook 미발송 가능) |
| (그 외 / undefined) | `open` | **기존 polar.adapter.ts:mapCheckoutStatus 동작 보존** (reconciliation false positive 차단) |

#### DB Payment.status 어휘 (PAYMENT_STATUS)
| value | 진입 시점 |
|---|---|
| `pending` | initiatePayment 직후 (Polar checkout 진입 전) |
| `completed` | order.paid webhook + completePaymentAtomically 종료 |
| `failed` | webhook fail 수신 또는 SDK 결함 permanent_failed 박제 |
| `refunded` | 전액 환불 종료 (refundPaymentAtomically + RefundLog 박제) |
| `partial_refunded` | 부분 환불 종료 (PAY-P2-1 PartialRefund §17 정합) |

#### DB WebhookEvent.status 어휘 (WEBHOOK_EVENT_STATUS)
| value | 진입 시점 |
|---|---|
| `processed` | completePaymentAtomically 또는 refundPaymentAtomically 종료 |
| `skipped` | 중복 / unknown_trade / already_completed / already_refunded |
| `failed` | SDK 결함 또는 트랜잭션 결함 박제 |

### 대안
- (A) DB enum 변환 — Prisma `enum` 영역 schema 마이그레이션 (사용자 5/10 정합 X, 거부 — dev migration 0 강제)
- (B) Branded type (`type PaymentStatus = string & { __brand: 'PaymentStatus' }`) — Runtime 검증 부재 (거부, enum 영역 박제가 명시적)
- (C) zod schema 영역 정합화 — 외부 npm 의존 추가 (사용자 5/10 정합 X, 거부)
- (D) `as const` 객체 + TypeScript literal type ← **채택** (zero runtime cost + IDE 자동완성 + Runtime 검증 — 외부 의존 0건)

### 구현
- **domain/model**: `src/domain/model/payment-status.ts` (5 enum + 2 mapping function + 3 helper)
- **domain/model spec**: `src/domain/model/payment-status.spec.ts` (34 it — AC 매트릭스 정합)
- **polar.adapter 통합**: `src/adapter/outbound/payment/polar.adapter.ts` (import + private 메서드 영역 도메인 helper 위임)
- **payment.usecase 통합**: `src/application/payment/payment.usecase.ts` (import + `isPaymentAlreadyRefunded` + `NORMALIZED_WEBHOOK_STATUS.SUCCESS/CANCEL` + `PAYMENT_STATUS.COMPLETED` + `WEBHOOK_EVENT_STATUS.PROCESSED` 1회 영역)
- **sensor**: `.claude/scripts/sensor-payment-status-mapping.sh` (10 검증)
- **regression**: `eval/tasks/regression-72-payment-status-mapping.json` (10 criteria)

### 결과
- 도메인 매핑 함수 영역 헥사고날 DIP 정합 (polar.adapter.ts private 메서드 영역 도메인 helper 위임)
- 어휘 통일 — TypeScript IDE 자동완성 + 오타 영역 컴파일 단계 차단
- `isPaymentAlreadyRefunded` race condition 통합 게이트 — §22 PaymentRaceCondition 정합 강화
- jest 735 → 769 PASS (+34 it — payment-status spec 영역)
- sensor-payment-race-condition 패턴 영역 helper 호출 영역 정합화 (회귀 보존)
- DB schema 0건 / dev migration 0건 / 외부 API 0건 정합 강제

### 정합 매트릭스 (다른 sprint 회귀 차단)
- §22 PaymentRaceCondition 정합 — `isPaymentAlreadyRefunded` 통합 helper 영역 sensor pattern 정합 보정
- §11 WebhookEventIdempotency 정합 — `WEBHOOK_EVENT_STATUS` enum 어휘 통합 (DB String 컬럼 유지 + TypeScript 어휘 통일)
- §12 PaymentReconciliation 정합 — `NORMALIZED_CHECKOUT_STATUS` enum 영역 어휘 통합 (default → 'open' 동작 보존)
- §13 RefundPaymentAtomically 정합 — `REFUND_SOURCE` enum 영역 'webhook' / 'manual' 어휘 통합
- §17 PartialRefund 정합 — `PAYMENT_STATUS.PARTIAL_REFUNDED` enum 영역 어휘 통합 (REFUNDED_STATES 정합)
- §24 PolarSDKTimeoutPolicy 정합 — Polar SDK exception 분류 영역 0 영향 (status 매핑 영역만)
- §27 CircuitBreakerPolicy 정합 — circuit breaker 영역 status 매핑 영역 0 영향

### 잔존 영역
- DB schema 영역 enum 변환 — Prisma `enum` 마이그레이션 (별도 sprint PAY-P4-x 영역 후보)
- 4 status literal 위치 영역 통합 — payment.usecase.ts 영역 status: 'processed' 영역 추가 통합 (회귀 최소화 정합으로 1회만 박제, 향후 sprint 영역 후속)
- 다른 사용 영역 (admin.usecase / refund-payment.usecase 등) — 어휘 통합 영역 후속 sprint 후보

### 정본 영역
- `grimoire-server/src/domain/model/payment-status.ts`
- `grimoire-server/src/domain/model/payment-status.spec.ts`
- `grimoire-server/ADR.md §ADR-010`
- `.claude/scripts/sensor-payment-status-mapping.sh`
- `eval/tasks/regression-72-payment-status-mapping.json`

### 변경 이력
- 2026-05-15 #10_8 PAY-P3-D: 신설 — Status enum + Polar 매핑 정책 박제 (사용자 5/15 verbatim 4번째 sprint). 5 enum (PAYMENT_STATUS / WEBHOOK_EVENT_STATUS / NORMALIZED_WEBHOOK_STATUS / NORMALIZED_CHECKOUT_STATUS / REFUND_SOURCE) + 2 매핑 함수 (mapPolarOrderStatus / mapPolarCheckoutStatus) + 3 helper (isPaymentAlreadyRefunded / isPolarRefundedStatus / isPolarSuccessStatus). 헥사고날 DIP 정합 강화. DB schema 0 / dev migration 0 / 외부 API 0 강제. jest 735 → 769 PASS (+34 it). 정본: `payment-status.ts` + `payment-status.spec.ts` + `ADR.md ADR-010`.

---

## 29. UserSoftDeletePolicy (server 도메인 — Author Soft Delete + 본인 탈퇴 + 운영자 강제 삭제 + GDPR 익명화 + 30일 cron hard delete)

> Sprint USER-SOFT-DELETE (2026-05-15 #10_8) — 사용자 5/15 verbatim "B + A 모두 진행" 정합. PAY-P3-E sprint 단계 1~6 종료 직후 5번째 sprint.

### 위치 (Hexagonal 정합 박제)

- **model**: `grimoire-server/src/domain/model/author.ts` (deletedAt 필드 + isAuthorDeleted 검증 함수)
- **enum**: `grimoire-server/src/domain/model/user-soft-delete-state.ts` (SoftDeleteState + SoftDeletedBy)
- **policy**: `grimoire-server/src/domain/policy/user-soft-delete-policy.ts` (30일 정책 + GDPR 익명화 정책 + 환경변수 로드 + computeHardDeleteCutoff)
- **port**: `grimoire-server/src/domain/port/outbound/user-anonymizer.port.ts` (UserAnonymizerPort 인터페이스)
- **port 확장**: `grimoire-server/src/domain/port/outbound/author-repository.port.ts` (softDelete / restore / hardDeleteOlderThan / findDeletedById / findDeletedOlderThan 메서드)
- **adapter (middleware)**: `grimoire-server/src/adapter/outbound/persistence/prisma-soft-delete.middleware.ts` (Prisma `$use` 영역 자동 변환)
- **adapter (anonymizer)**: `grimoire-server/src/adapter/outbound/persistence/default-user-anonymizer.adapter.ts` (basic 옵션 A)
- **usecase**: `grimoire-server/src/application/author/user-soft-delete.usecase.ts` (본인 탈퇴 + 운영자 강제 삭제)
- **cron**: `grimoire-server/src/application/author/user-hard-delete.job.ts` (`@Cron('0 0 4 * * *')` 매일 새벽 4시)
- **controller (self)**: `grimoire-server/src/adapter/inbound/http/controller/author.controller.ts` (`@Delete('me')`)
- **controller (admin)**: `grimoire-server/src/adapter/inbound/http/controller/admin.controller.ts` (`@Post('authors/:authorId/force-delete')` + `@Post('authors/:authorId/anonymize')` qa #20 보강)
- **migration**: `grimoire-server/prisma/migrations/20260515_user_soft_delete_policy/migration.sql` (ALTER TABLE authors ADD COLUMN deleted_at + CREATE INDEX)
- **spec**: 4 spec (user-soft-delete.usecase.spec / user-hard-delete.job.spec / prisma-soft-delete.middleware.spec / default-user-anonymizer.adapter.spec — total ≥ 20 it) + admin.controller.spec.ts (anonymize 엔드포인트 영역 spec ≥ 1 it, qa #20 보강)
- **ADR**: `grimoire-server/ADR.md ADR-011`
- **env**: `USER_SOFT_DELETE_RETENTION_DAYS` (기본 30) / `USER_SOFT_DELETE_CRON_TIME` (기본 '0 4 * * *') / `GDPR_ANONYMIZE_SCOPE` (기본 'basic') / `USER_HARD_DELETE_DISABLED` (게이트)
- **sensor**: `.claude/scripts/sensor-user-soft-delete-policy.sh` (13 검증 — qa #20 보강 영역 anonymize 엔드포인트 박제 +1)
- **eval**: `eval/tasks/regression-73-user-soft-delete-policy.json`

### 시그니처

```typescript
// 4 상태 enum (user-soft-delete-state.ts)
export enum SoftDeleteState {
  ACTIVE = 'ACTIVE',
  SOFT_DELETED = 'SOFT_DELETED',
  ANONYMIZED = 'ANONYMIZED',
  HARD_DELETED = 'HARD_DELETED',
}
export type SoftDeletedBy = 'self' | 'admin'

// 정책 (user-soft-delete-policy.ts)
export interface UserSoftDeletePolicy {
  retentionDays: number          // 기본 30
  cronTime: string               // 기본 '0 4 * * *'
  anonymizeScope: 'basic' | 'strong' | 'strongest'  // 기본 'basic'
}

// Port (user-anonymizer.port.ts)
export interface UserAnonymizerPort {
  anonymize(authorId: string, scope?: 'basic' | 'strong' | 'strongest'): Promise<void>
}

// Repository port 확장 (author-repository.port.ts)
softDelete(id: string): Promise<void>
restore(id: string): Promise<void>
hardDeleteOlderThan(cutoff: Date): Promise<{ deletedIds: string[]; blockedIds: string[] }>
findDeletedById(id: string): Promise<Author | null>
findDeletedOlderThan(cutoff: Date): Promise<Author[]>

// UseCase (user-soft-delete.usecase.ts)
async execute(
  authorId: string,
  deletedBy: SoftDeletedBy,
  adminId?: string,   // admin 영역 필수
  reason?: string,    // admin 영역 필수
): Promise<void>

// UseCase anonymize-only 분기 (qa #20 server-web 정합 보강 — 2026-05-15)
// GDPR Article 17 only — 계정 유지 + email/name/passwordHash/bio 4 필드 익명화
async anonymizeOnly(
  authorId: string,
  adminId: string,    // 필수
  reason: string,     // 필수
): Promise<{ anonymizedAt: string }>
```

### 적용 매트릭스 (사용자 5/15 결정 옵션 A 5건 정합)

| 결정 영역 | 옵션 | 채택 |
|---|---|---|
| User soft delete | A (User.deletedAt DateTime?) | ✅ |
| 작품/episode cascade | A (PAY-P3-E Restrict 정합, archive 0건) | ✅ |
| GDPR 익명화 범위 | A (basic — email + name + passwordHash + bio) | ✅ |
| 30일 hard delete | A (자동 cron + 회계 차단 시 보류) | ✅ |
| cron 시간 | A (`0 4 * * *` 매일 새벽 4시) | ✅ |

### Hexagonal 흐름 매트릭스

```
[Author 본인 탈퇴]
  HTTP DELETE /api/v1/authors/me (JWT 인증)
    → AuthorController.deleteMyAccount(authorId)
    → UserSoftDeleteUseCase.execute(authorId, 'self')
      → AuthorRepositoryPort.softDelete (middleware 자동 변환 정합)
      → UserAnonymizerPort.anonymize (basic 옵션 A)
      → AuthTokenRepositoryPort.revokeAllByAuthorId (PAY-P3-E Cascade 정합 강화)
      → AuditLog.log('self', 'self_account_delete', ...)
      → AuditLog.log('self', 'gdpr_anonymize', ...)

[운영자 강제 Author 삭제]
  HTTP POST /api/v1/admin/authors/:id/force-delete (AdminGuard + 사유 영역 필수)
    → AdminController.forceDeleteAuthor(authorId, body.reason)
    → UserSoftDeleteUseCase.execute(authorId, 'admin', adminId, reason)
      → ... (위와 동일) +
      → AuditLog.log(adminId, 'admin_force_delete', authorId, { reason, ... })

[운영자 GDPR 익명화 only — qa #20 server-web 정합 보강 (2026-05-15)]
  HTTP POST /api/v1/admin/authors/:id/anonymize (AdminGuard + 사유 영역 필수)
    → AdminController.anonymizeAuthor(authorId, body.reason)
    → UserSoftDeleteUseCase.anonymizeOnly(authorId, adminId, reason)
      → UserAnonymizerPort.anonymize (basic — email + name + passwordHash + bio)
      → AuditLog.log(adminId, 'gdpr_anonymize', authorId, { reason, scope, mode: 'anonymize_only', beforeState, afterState })
      → soft delete X (계정 유지)
      → RefreshToken revoke X (탈퇴 영역 영역 영역)

[30일 후 cron hard delete]
  @Cron('0 0 4 * * *') 매일 새벽 4시 KST
    → UserHardDeleteJob.hardDeleteExpiredUsers
      → AuthorRepositoryPort.hardDeleteOlderThan (raw query 영역 영역 회피 + try-catch P2003)
      → deletedIds[] → AuditLog '30d_hard_delete'
      → blockedIds[] → AuditLog '30d_hard_delete_blocked' (회계 8건 Restrict)
```

### Prisma middleware 자동 변환 매트릭스 (Author 모델 영역만)

| Prisma 작업 | 자동 변환 |
|---|---|
| `findUnique` | → `findFirst` + WHERE deletedAt: null |
| `findFirst` / `findFirstOrThrow` | + WHERE deletedAt: null |
| `findMany` / `count` | + WHERE deletedAt: null |
| `delete` | → `update { deletedAt: NOW() }` |
| `deleteMany` | → `updateMany { deletedAt: NOW() }` |
| `args.where.includeDeleted: true` | 우회 (flag 제거 + middleware skip) |

### AdminAuditLog 4 action 박제 (PAY-P2-4 6-arg 정합)

- `self_account_delete` — 사용자 본인 탈퇴 (DELETE /me 영역)
- `admin_force_delete` — 운영자 강제 삭제 (사유 필수, AdminGuard 영역)
- `gdpr_anonymize` — GDPR 익명화 (별도 audit log 박제)
- `30d_hard_delete` — 30일 cron 영역 hard delete 성공
- `30d_hard_delete_blocked` — 30일 cron 영역 회계 Restrict P2003 차단 영역 보류

### 회계 8건 Restrict 정합 박제 (PAY-P3-E 정합 강제)

PAY-P3-E 단계 1~6 종료 박제 정합 — Author hard delete 시 PG 자동 차단:
- payments (onDelete=Restrict)
- credit_logs (onDelete=Restrict)
- analysis_reports (onDelete=Restrict)
- user_sanctions (onDelete=Restrict)
- refund_logs (Payment Cascade 영역 정합)
- admin_audit_logs (onDelete=Restrict, adminId)
- works (onDelete=Restrict, authorId)
- webhook_events / webhook_retry_queues (Payment Cascade 영역 정합)

cron 30일 hard delete 영역 영역 — 회계 row 영역 영역 영역 P2003 catch → 보류 (영구 soft delete 상태 유지 + audit log 박제).

### 정합 매트릭스

- PAY-P3-E (§25 FKCascadePolicy) 강화 — 33 FK + 회계 8건 Restrict 정합 박제
- PAY-P3-E RefreshToken Cascade 정합 강화 — soft delete 시점에 별도 revokeAll 호출
- PAY-P2-4 (§20 AdminAuditLog beforeState/afterState) 정합 — 6-arg 시그니처 + 4 action 신설
- PAY-P2-5 (§26 AuditRetentionPolicy) 정합 — soft delete 영역 audit log 영구 보존 + 90일 PII 마스킹

### 변경 이력
- 2026-05-15 #10_8 USER-SOFT-DELETE: 신설 — Author soft delete + 본인 탈퇴 + 운영자 강제 삭제 + GDPR 익명화 + 30일 cron hard delete 정합 박제 (5번째 sprint, 사용자 5/15 verbatim "B + A 모두 진행" 정합). DB schema 1 (User.deletedAt + @@index) + dev migration 1 (NULL ALLOW + INDEX) + 외부 API 0. jest 769 → 797 PASS (+28 it). 정본: `prisma/schema.prisma` Author + `user-soft-delete-policy.ts` + `user-soft-delete.usecase.ts` + `user-hard-delete.job.ts` + `prisma-soft-delete.middleware.ts` + `default-user-anonymizer.adapter.ts` + `ADR.md ADR-011`.
- 2026-05-15 #10_8 USER-SOFT-DELETE anonymize 엔드포인트 보강 (qa #20 server-web 정합 CRITICAL 해소): `@Post('authors/:authorId/anonymize')` 신설 (admin.controller.ts) + `anonymizeOnly` UseCase 분기 신설 (user-soft-delete.usecase.ts) + admin.controller.spec.ts 신규 (2 it) + user-soft-delete.usecase.spec 6 it 추가 + sensor 12→13 검증 + eval regression-73 12→13 criteria. jest 797 → 805 PASS (+8 it). DB schema 0 + dev migration 0 + 외부 API 0. 응답 시그니처 `{ anonymizedAt: string }` — web `adminAnonymizeAuthor` 호출 정합.

---

## 30. CreditOverhaul (server 도메인 — 크레딧 디노미네이션 + 출처 회계 + 채팅 4구간 차감)

**위치**: `grimoire-server/src/domain/model/credit-point.ts`, `credit-source.ts`, `chat-charge-tier.ts`, `membership-tier.ts`
**적용**: charge-points.usecase.ts / grant-points.usecase.ts / reset-monthly-pool.job.ts / chat.usecase.ts / novel-analysis.usecase.ts

크레딧 개편 I Phase (2026-05-17) — 디노미네이션 1:1,000 + 포인트 출처 4종 분리 회계 + 채팅 4구간 사후 차감.
정본: `research/CREDIT_PRICING_OVERHAUL_PLAN.md` §8 (v6) + `.claude/state/sprint-credit-overhaul-s-phase-draft.md` + ADR-012.

### 인터페이스 (TypeScript)

```typescript
// 디노미네이션 상수 — 1 크레딧 = 1,000pt (§8-1)
export const CREDIT_TO_POINT = 1000;

// 포인트 출처 4종 (§8-2 분리 회계)
export type CreditSource = 'free' | 'subscription' | 'gift' | 'charged';

// ledger 엔트리 타입
export type CreditLedgerType = 'earn' | 'spend' | 'deficit_incur' | 'deficit_settle' | 'expire';

// 소진 우선순위 (§8-2) — 인덱스 0이 최우선 소진
export const CREDIT_CONSUMPTION_ORDER: readonly CreditSource[] = ['free', 'subscription', 'gift', 'charged'];

// 채팅 4구간 차감 (§8-4 — 경계값은 SystemSetting 동적, 아래는 §8 기본값)
//   short ≤500tok=190pt / normal 501~4,000=810pt / long 4,001~12,000=3,390pt / xlong >12,000=5,520pt

// 분석·테마 정액 차감 (§8-4)
export const ANALYSIS_POINT_COST = 2440;  // 구 ANALYSIS_CREDIT_COST=4 디노미 환산
export const THEME_POINT_COST = 590;      // 구 1 크레딧 디노미 환산

// 멤버십 등급 + 월 포인트 풀 (§8-3)
export type MembershipTier = 'free' | 'pro' | 'premium';
export const MEMBERSHIP_MONTHLY_POOL: Record<MembershipTier, number> = { free: 0, pro: 93000, premium: 191500 };

// CreditLedgerPort (domain/port/outbound/credit-ledger.port.ts)
export interface CreditLedgerPort {
  earn(input: EarnInput): Promise<CreditLedgerEntry>;            // 적립 (가입/충전/응원선물/구독풀)
  spend(input: SpendInput): Promise<SpendResult>;                // 소진 (우선순위 적용 + 잔액 부족 시 deficit)
  getBalance(authorId: string): Promise<CreditBalance>;          // 출처별 잔액 + deficit
  settleDeficit(authorId: string, fromAmount: number): Promise<number>;  // 충전 시 deficit 우선 상계
  findByAuthor(authorId: string, limit: number): Promise<CreditLedgerEntry[]>;
}
export interface SpendResult {
  spentBySource: Record<CreditSource, number>;  // 출처별 차감액
  deficitIncurred: number;                       // 외상 발생분 (잔액 부족, 정상 시 0)
  balanceAfter: number;
}
export interface CreditBalance {
  free: number; subscription: number; gift: number; charged: number;
  total: number;      // 4 출처 합
  deficit: number;    // Author.deficitPoints (외상)
  available: number;  // total - deficit
}

// HTTP 응답 DTO — GET /credits/balance · GET /payments/credits (adapter/inbound/http/dto/credit.dto.ts)
//   도메인 CreditBalance(flat) → web point-balance.ts normalizePointBalance 가 받는 bySource 중첩 형태
export interface CreditBalanceResponseDto {
  available: number; total: number; deficit: number;
  bySource: { free: number; subscription: number; gift: number; charged: number };
}

// MembershipPlanPort (domain/port/outbound/membership-plan.port.ts)
export interface MembershipPlanPort {
  getPlan(authorId: string): Promise<MembershipPlanState | null>;
  resetMonthlyPool(authorId: string, now: Date): Promise<void>;  // 월간 리셋 (이월 금지 — §8-8 #2)
  findPlansToReset(now: Date): Promise<MembershipPlanState[]>;
  changeTier(authorId: string, tier: MembershipTier, now: Date): Promise<MembershipPlanState>;
}

// ClaudeApiPort 확장 — 채팅 사후 차감용 토큰 usage 노출
askWithUsage(systemPrompt: string, userMessage: string, options?: AskOptions): Promise<ClaudeAskResult>;
// ClaudeAskResult: { text, inputTokens, outputTokens, model }
```

### DB 모델 (Prisma)

- **CreditLedger** (신설) — `authorId` FK Restrict / `source` / `type` / `amount`(부호 有) / `balanceAfter` / `expiresAt?`(구독풀 만료) / `reason` / `relatedId?`. 인덱스 `[authorId,createdAt]` `[authorId,source]` `[expiresAt]`.
- **MembershipPlan** (신설) — `authorId` FK Restrict / `tier` / `monthlyPoolPoints` / `poolBalance` / `poolResetAt` / `polarSubscriptionId?` / `status`. 인덱스 `[authorId]` `[poolResetAt]` `[status]`.
- **Author** — 4 필드 추가 (`pointsFree`/`pointsSubscription`/`pointsGift`/`pointsCharged` 잔액 캐시) + `deficitPoints`. `credits` 는 `[DEPRECATED]` (1 sprint 유예 후 DROP).
- **ChatMessage** — 5 필드 추가 (`inputTokens?`/`outputTokens?`/`model?`/`chargedPoints?`/`chargeTier?`, 전부 nullable).

### 변경 시 동시 갱신 대상

- `grimoire-server/src/domain/model/credit-point.ts` / `credit-source.ts` / `chat-charge-tier.ts` / `membership-tier.ts` / `credit-system-setting.ts`
- `grimoire-server/docs/ai-cost-table.md` §0·§2·§3 (cost-accountant 단독 관리 — 차감 N 변경 시 §0 재검증)
- `grimoire-server/docs/ai-analysis-spec.md` (분석 차감 pt)
- `grimoire-server/docs/data-model.md` + `SCHEMA.md` (CreditLedger / MembershipPlan / Author / ChatMessage)
- `grimoire-web` 잔액 표시 + 채팅 차감 안내 + 구독 플랜 + 충전 패키지 UI (web Generator — I Phase)
- `eval/tasks/regression-74~77-*.json` + `.claude/scripts/sensor-credit-*.sh` (5종)

### §7 `ANALYSIS_CREDIT_COST` 이행 관계

기존 §7 `ANALYSIS_CREDIT_COST = 4` (정수 크레딧)는 본 §30 `ANALYSIS_POINT_COST = 2440` (디노미 pt)로 이행.
`novel-analysis.usecase.ts` 가 `ChargePointsUseCase` 주입 시 디노미 차감, 미주입 시 구 경로(BACKWARD COMPATIBLE).

### 변경 이력

- 2026-05-17 #크레딧개편 I Phase: 신설 — grimoire-server. 디노미네이션 1:1,000 + 포인트 출처 4종 분리 회계(1-C 하이브리드: Author 4 필드 캐시 + CreditLedger 원장) + 구독 월 풀(MembershipPlan, 4-C 이월 금지) + 채팅 4구간 사후 차감(190/810/3,390/5,520pt) + 분석 2,440pt / 테마 590pt. DB schema 변경(CreditLedger/MembershipPlan 신설 + Author 5 필드 + ChatMessage 5 필드) + migration 파일 작성(apply 0건). jest 805 → 967 PASS (+162 it). cost-accountant 승인 `786b0f3`. 정본: ADR-012 + S Phase Draft. sensor 5종 신설(credit-overhaul-recalc / credit-denomination / credit-source-accounting / subscription-pool-no-rollover / chat-charge-tier).
- 2026-05-17 #크레딧개편 I Phase web Generator: grimoire-web — §30 인터페이스 미변경(소비만). `src/features/credits/` 슬라이스 신설(credit-overhaul.ts §30 상수 미러 + point-balance.ts `/credits/balance` 응답 정규화 + CreditBalanceCard / ChatChargeGuide / MembershipPlans + 채팅 ChatChargeBadge). `/dashboard/credits` 디노미 개편 + `/dashboard/membership` 신설 + `/dashboard/chat` 4구간 차감 배지. **server I Phase backward-compatible 확인**: `/credits/balance`·`/auth/me`·`/payments/products` HTTP 응답 미변경(정수 크레딧 / 구 3 패키지), `CreditLedger.getBalance`(4 출처)·`MembershipPlan`은 HTTP 미연동 — web 은 server 실제 반환값에만 의존(없는 출처값 추정 금지, 잔액 정수 크레딧 ×1,000 환산). `ChatMessage.chargedPoints`/`chargeTier`만 실제 응답 포함. vitest 160→210 PASS (+50 it). 후속(별도 sprint): `MembershipPlanPort` HTTP 노출 시 멤버십 결제 UI / `CreditLedger.getBalance` HTTP 노출 시 4 출처 분해 자동 활성 / `CREDIT_PRODUCTS` #7 4종 갱신 시 패키지 자동 반영.
- 2026-05-17 #크레딧개편 I Phase HTTP follow-up: grimoire-server — `GET /credits/balance` + `GET /payments/credits` 를 4 출처 `CreditBalanceResponseDto`(available/total/deficit/bySource)로 노출(기존 `{credits:number}` → 새 모델). `CreditUseCase.getPointBalance()` 신설 — `CreditLedgerPort.getBalance` 위임. web `point-balance.ts normalizePointBalance` 가 `bySource` 자동 분해 → 4 출처 표시 활성. jest 967→971 PASS (+4 it). 커밋 `1ba8c9f`→`9d0d2b7`. web Generator §0 검증으로 발견된 HTTP 미연동 갭(draft §5) 해소. 잔여(별도 sprint): `CREDIT_PRODUCTS` #7 4종(Polar 상품 등록 종속) / `MembershipPlanPort` HTTP 노출.

---

## 변경 시 절차 (책 Ch 16 충돌 2번 해결책)

agent A가 인터페이스 변경 시:
1. **즉시 본 파일 해당 섹션 갱신**
2. **변경 이력 1줄 박제** (date — agent — 변경 요약)
3. **agents/.md에 참조 박제 누락 시 추가**
4. **다른 agent가 통합 단계에서 본 파일 참조 → drift 0건 보장**

---

## 관련 정본
- `.claude/knowledge/agent-interaction-matrix.md` — 7×7 핸드오프 메타 (본 파일은 인터페이스 본문)
- `.claude/knowledge/agent-system.md` — 에이전트 역할 분담
- `AUTOMATION.md` §1 — 에이전트 인벤토리
- `research/HARNESS_ENGINEERING.md` Ch 16 멀티 에이전트 — 책 권장 패턴
- `CLAUDE.md` §14 — 메인 Claude 오케스트레이션 규칙

---

마지막 업데이트: 2026-04-27 (P1 도입)
승격 원본: "하네스 엔지니어링 완전 정복" Ch 16 + cost-accountant 7번째 위임
