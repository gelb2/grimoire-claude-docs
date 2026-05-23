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
- 2026-05-20 #크레딧개편 CC-2b 환불 신 경로 + 이중 외상 통합: grimoire-server — `PaymentRepositoryPort.refundPaymentWithPoints` 신설(CC-2a `completePaymentWithPoints` 대칭 案 R1). 단일 `$transaction` — authors FOR UPDATE + 비례 계산(PAY-P2-1) + 4 출처 환수(charged→gift→subscription→free 우선) + 부족분 `Author.deficitPoints` 가산 + `CreditLedger` `type='deficit_incur'` row(reason=`refund_deficit:..`) + `RefundLog` 박제. `$executeRawUnsafe` CAS race 차단 이식(PAY-P3-A). 도메인 헬퍼 `computeRefundLedgerEntries` + `REFUND_RECOVERY_ORDER` 추출. **이중 외상 통합**: 외상 정본을 `Author.deficitPoints` 단일화 — 다음 충전 시 CC-2a `completePaymentWithPoints` 가 자동 회수(구 시스템 `RefundLog.deficitCredits` 영구 외상 해소). `RefundLog.credits`/`deficitCredits` 컬럼 의미 재해석(pt 단위 + "이 환불 1건이 유발한 외상 pt 기여분") — 물리 rename 0건, CC-4 위임. **인터페이스 변경**: `refund-payment.usecase.execute` 입력 `credits→refundPt`, 반환 `{actualDeducted/deficitCredits/proportionalCredits→actualRefunded/deficitIncurred/proportionalPt}`. `RefundPaymentUseCase` 생성자에 `CreditLedgerPort` Optional 추가(beforeState 4 출처 디노미 정합). 구 `refundPaymentAtomically` `@deprecated` 보존(회귀 안전망 — CC-3/CC-4 후 제거). 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §1-C + `.claude/state/sprint-cc2b-gift-refund-wiring-plan-draft.md` §4-2/§5.
- 2026-05-21 #크레딧개편 CC-4 Phase 1 구 메서드 제거: grimoire-server — `PaymentRepositoryPort.refundPaymentAtomically` + `completePaymentAtomically` 시그니처 + `PrismaPaymentRepository` 본문 완전 제거. 모든 충전·환불 경로는 `completePaymentWithPoints` / `refundPaymentWithPoints`(신 포인트 원장) 단일. PAY-P3-A CAS race 차단 + PAY-P2-1 부분 환불 비율 회귀 spec 은 신 메서드 describe 에 동등 박제 + `credit-rollover-source-ledger-integration.spec.ts` CC-4 P1 통합 describe 신설(admin·discovery 신·구 분열 해소 + ledger.sumSpendByAuthor 위임 박제). Phase 2(컬럼 rename) / Phase 3(`Author.credits` DROP / `CreditLog` 폐기) 별도 sprint. 정본: `.claude/state/sprint-cc4-postcleanup-plan-draft.md` §3-1/§3-2 P1d·P1e.
- 2026-05-21 #크레딧개편 CC-4 Phase 2 Payment.credits → points 물리 rename + RefundLog 案 Y 보존: grimoire-server — ① `Payment.credits Int` → `Payment.points Int` 물리 rename (마이그레이션 `20260521_payment_credits_rename_phase2` — `ALTER TABLE "payments" RENAME COLUMN "credits" TO "points"`, Postgres native, 메타데이터 한정 락, 비파괴). Prisma schema + `PaymentRepositoryPort.PaymentRecord` + `create()` 입력 `credits→points` 정합. ② **RefundLog 案 Y 보존**: `RefundLog.credits` + `RefundLog.deficitCredits` 컬럼 DDL 변경 0건. 의미 박제 강화 (`schema.prisma:535-542` 주석 — `credits = 실 환수 pt(actualRefunded), Payment.points 와 단위 일관` / `deficitCredits = 이 환불 1건이 유발한 외상 pt 기여분(감사 추적용), 외상 잔액 정본은 Author.deficitPoints`). 보존 사유 = 명명 충돌 회피(Author.deficitPoints) + 회귀 범위 최소화(admin/audit 전용, HTTP 미노출). ③ 코드 일괄 rename 영향 — `payment.usecase.ts`(initiatePayment create / completePaymentWithPoints / refundPaymentUseCase.execute 호출 / processWebhook audit meta) / `payment-reconciliation.job.ts`(handleBoost / handleRefundMismatch audit meta `credits→points`) / `prisma-payment.repository.ts`(create 시그니처 + refundPaymentWithPoints 내부 `payment.points` select / 주석) / `refund-payment.usecase.ts`(JSDoc 1건) / `domain/model/config.ts`(주석 2줄) / spec 7 파일(`payment.usecase.spec`/`payment-charge-credit-integration.spec`/`credit-gift-refund-integration.spec`/`payment-reconciliation.job.spec`/`payment-cleanup.job.spec`/`webhook-retry.job.spec`/`prisma-payment.repository.spec`) PaymentRecord mock + tx.payment.findUnique mock 일괄 `credits→points`. ④ **응답 키 보존**: `processNormalizedWebhook` 반환 `{ processed, credits, deficitCredits? }` 키는 외부 호환성(payment.controller webhook 응답 + DLQ retry 결과) 위해 그대로 유지 — 내부 컬럼명만 변경. ⑤ HTTP 응답 영향 0 — `GET /payments/products` 응답 키는 이미 CC-2a 박제(`points`/`pricePerPoint`), `GET /payments/credits` 응답은 CC-3 박제(`bySource.charged`). jest 1063→1063 PASS (변동 0 — assertion 키만 변경, 신설 it 0). 커버리지 61.74%(stmts) / 63.33%(lines) — 게이트 ≥60% 충족. 빌드 + tsc 통과. 로컬 dev DB migration apply PASS — 사후 검증 SQL 4건 PASS(`payments.points` 컬럼 존재 / 구 `credits` 컬럼 0건 / row count 0 일치 / `refund_logs.credits`·`deficit_credits` 보존). cost-accountant/visual-canon-keeper 게이트 불요(신규 AI 0건, UI 영향 0건). **Payment.points 정합 종결 증명**: `grep "payment\.credits\|Payment\.credits" src --include="*.ts" --exclude="*.spec.ts"` = 주석 매치 2건만(rename 박제 이력 자체) — 코드 본문 호출 0건. Phase 3(`Author.credits` DROP + `CreditLog` 폐기 + `prisma-credit.repository` 잔존 메서드 제거 + `auth.controller:48`/`refund-payment.usecase:124-125`/`credit-migration.ts` 정리) 별도 sprint(≥1 sprint 운영 박제 후, Cursor 반면교사). HIGH-1 案 B = Case C 별도 sprint(사용자 결정 5/21). 정본: `.claude/state/sprint-cc4-phase2-rename-plan-draft.md` (案 Y RefundLog 보존 권고 채택).

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

> **메서드 정합 (CC-2b 이후)**: `refundPaymentAtomically` 는 CC-2b(2026-05-20)에서 `refundPaymentWithPoints` 로 전면 재작성됨 (4 출처 환수 + 이중 외상 통합). 본 §17 의 구 `refundPaymentAtomically` 시그니처/처리 흐름은 §13(CreditLedger) + 본 절 PAY-S2 박제로 갱신. `credits`→`refundPt`, `actualDeducted`→`actualRefunded`, `deficitCredits`→`deficitIncurred`(반환), `proportionalCredits`→`proportionalPt` 로 어휘 이행됨.

- **비율 계산 (트랜잭션 내부)**: `ratio = refundedAmount / payment.amount` (`prisma-payment.repository.ts`)
- **비례 포인트**: `proportionalPt = isPartial ? Math.floor(refundPt * ratio) : refundPt`
- **반올림 정책**: `Math.floor` 고정 (사용자 우호 — 차감 ↓ 소수점 버림)
- **isPartial 분기**: `ratio < 1.0` (전액 환불은 PAY-P1-1 회귀 보존)
- **Payment.status 분기**: 부분 환불 시 `'partial_refunded'`, 전액 시 `'refunded'`
- **Validation** (전부 `$transaction` 내부 — Payment 조회 + authors FOR UPDATE 와 같은 tx):
  - `refundedAmount <= 0` → throw (메서드 진입부)
  - `payment.amount <= 0` → throw (free 결제 환불 무의미)
  - **누적 한도 검증 (PAY-S2 / HIGH-1 — 2026-05-22)**: `tx.refundLog.aggregate({ where: { paymentId }, _sum: { amount } })` 로 이 paymentId 에 이미 박제된 RefundLog 환불 누적 합계 조회 → `priorRefundedAmount + refundedAmount > payment.amount` 시 throw(`환불 누적 한도 초과`). **구 단건 검사(`refundedAmount > payment.amount`)를 흡수** — 기존 환불 누적이 0이면 단건 검사와 동치. `tx` 핸들 + authors FOR UPDATE 직렬화로 race 0건.

### 누적 한도 검증 (PAY-S2 — HIGH-1 depth-in-defense)

- **결함 (HIGH-1)**: CC-2b 가 `refundPaymentAtomically`→`refundPaymentWithPoints` 재작성 시 누적 검증 미이식. `RefundLog` 는 `paymentId` 1:N(PAY-P2-1 다중 부분환불 호환 설계)이나 런타임 검증은 단건뿐 — payment.amount=10,000 → 1차 부분환불 6,000 통과 → 2차 6,000 도 `6000 > 10000` false 라 통과 → 누적 12,000 적자.
- **설계-런타임 정합 명문화**: `RefundLog` paymentId 1:N 은 다중 부분환불 호환 설계, **단** 현 런타임 정식 지원은 1회 부분환불까지(webhook 경로는 `isPaymentAlreadyRefunded` 게이트가 `partial_refunded` 2회차 차단). PAY-S2 누적 검증은 게이트 우회 경로(reconciliation 수동 환수 / 향후 admin 다회 부분환불)가 도입돼도 **적자가 물리적으로 불가**하도록 하는 repository 메서드 자체 방어선(depth-in-defense).
- **案 A 채택 (정책 결정)**: `isPaymentAlreadyRefunded`(payment.usecase) **현행 게이트 유지** — webhook 2회차 차단, 회귀 0. 다중 부분환불 정식 지원(게이트 완화)은 PAY-S2 범위 밖(별도 PAY-P2 확장 — Polar webhook 다중 부분환불 송신 동작 확인 + reconciliation 정합 필요).
- **이중 방어**: ① payment.usecase `isPaymentAlreadyRefunded` 사전 게이트(webhook) ② `refundPaymentWithPoints` `$transaction` 내부 누적 검증(모든 경로 — webhook/manual/reconciliation).
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
4. `prisma-payment.repository.refundPaymentWithPoints` $transaction (CC-2b 재작성 — 4 출처 + 이중 외상):
   - authors row FOR UPDATE — 동시 차감/환수 직렬화
   - tx.payment.findUnique → amount/points/status 조회
   - validation (refundedAmount > 0 메서드 진입부, payment.amount > 0)
   - **PAY-S2 누적 한도 검증**: tx.refundLog.aggregate `_sum.amount` → `priorRefundedAmount + refundedAmount > payment.amount` 시 throw (단건 검사 흡수)
   - ratio = refundedAmount / payment.amount / isPartial = ratio < 1.0
   - proportionalPt = isPartial ? Math.floor(refundPt * ratio) : refundPt
   - tx.payment.update → status='partial_refunded'|'refunded'
   - `computeRefundLedgerEntries` → 4 출처 환수액(charged→gift→subscription→free) + 부족분
   - 출처별 CAS UPDATE(`updateMany WHERE 컬럼>=환수액 decrement`) + `CreditLedger source=출처 type='spend'` row
   - 부족분 → `Author.deficitPoints += deficitIncurred` + `CreditLedger type='deficit_incur'` row
   - tx.refundLog.create → amount=refundedAmount + credits=totalRecovered + deficitCredits=deficitIncurred
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
- 2026-05-22 PAY-S2 server: 다중 부분환불 누적 한도 검증 추가 (HIGH-1 해소). `refundPaymentWithPoints` `$transaction` 내부에 `tx.refundLog.aggregate _sum.amount` 로 기존 환불 누적 합계 조회 → `누적 + refundedAmount > payment.amount` 시 throw(`환불 누적 한도 초과`). 구 단건 검사(`refundedAmount > payment.amount`)를 누적 검증으로 흡수(병행 제거 — 누적 0이면 동치). 案 A 채택 — `isPaymentAlreadyRefunded` webhook 게이트 유지, 누적 검증은 depth-in-defense(게이트 우회 경로 적자 차단). 다중 부분환불 정식 지원은 범위 밖(PAY-P2 이월). CC-2b 재작성 시 미이식된 누적 검증 복구 + §17 구 `refundPaymentAtomically` 시그니처 stale 보정. spec +3 it(prisma-payment.repository.spec.ts `PAY-S2 — 누적 환불 한도 검증` describe) + 통합 spec FakeRepo 누적 검증 정합. jest 1094→1097 PASS / 커버리지 61.94% stmts. 마이그레이션 0건(기존 RefundLog 테이블 재활용). 정본: `reports/sprint-pay-s2-refund-cap-progress.md`.

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

> **메서드 정합 (CC-2b/CC-4 이후)**: `refundPaymentAtomically`(구 `Author.credits` 단일 컬럼) 는 CC-2b 에서 `refundPaymentWithPoints` 로 재작성됨 — 4 출처(charged/gift/subscription/free) 컬럼별 raw query CAS. 구 단일 `Author.credits` 컬럼은 CC-4 Phase 3 에서 DROP. 아래 CAS 는 출처별 컬럼(`points_charged` 등) 단위로 실행됨.

```typescript
// prisma-payment.repository.ts refundPaymentWithPoints $transaction 내부 (출처별 반복)
const column = sourceColumnSnake(source) // points_charged | points_gift | ...
const updateResult = await tx.$executeRawUnsafe(
  `UPDATE authors SET ${column} = ${column} - $1 WHERE id = $2 AND ${column} >= $1`,
  recovered,
  authorId,
)
if (updateResult === 0) {
  throw new Error(
    `CAS_MISMATCH — race condition detected on author.${column} ...`,
  )
}
```

### 정책

- **사전 게이트 (구멍-A)**: payment.status='refunded' OR 'partial_refunded' → skip (이미 환불 완료된 payment에 대한 재처리 방어 — 환불 후 재차감 0건 보장). 도메인 helper `isPaymentAlreadyRefunded` 위임 (§28 PaymentStatusMapping). **PAY-S2 案 A — 본 게이트 현행 유지** (다중 부분환불 정식 지원 = 별도 PAY-P2 확장).
- **CAS 패턴 (구멍-B)**: 출처별 `UPDATE ... WHERE 컬럼 >= 환수액` (Postgres atomic CAS) → 0 row 시 throw 'CAS_MISMATCH' → 호출자 retry 위임 (PAY-P2-2 DLQ)
- **누적 한도 검증 (PAY-S2 / HIGH-1 — 구멍-D 차단)**: `refundPaymentWithPoints` `$transaction` 내부 — `tx.refundLog.aggregate _sum.amount` 로 이 paymentId 환불 누적 합계 조회 → `priorRefundedAmount + refundedAmount > payment.amount` 시 throw. **게이트 우회 경로(reconciliation 수동 환수 / 향후 admin 다회 부분환불)가 도입돼도 누적 적자 물리적 불가** 보장 (depth-in-defense). 단건 검사 흡수 — 누적 0이면 동치. authors FOR UPDATE + 동일 `tx` 핸들 → race 0건. 정본: §17 PartialRefund 「누적 한도 검증」.
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
- 2026-05-22 PAY-S2 server: 구멍-D(다중 부분환불 누적 한도 미검증 — HIGH-1) 추가 차단. `refundPaymentWithPoints` `$transaction` 내부 `tx.refundLog.aggregate` 누적 검증 — 게이트 우회 경로(reconciliation 수동 환수 / admin 다회 부분환불)도 적자 물리적 불가. 案 A — `isPaymentAlreadyRefunded` webhook 게이트 현행 유지(구멍-A 방어선 보존). 구 `refundPaymentAtomically`/`Author.credits` 단일 컬럼 CAS 시그니처 stale 보정(CC-2b 4 출처 raw query CAS + CC-4 Phase 3 `Author.credits` DROP 반영). jest 1094→1097(+3 it). 마이그레이션 0건. 정본: `reports/sprint-pay-s2-refund-cap-progress.md` + §17 PartialRefund.

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
- **HTTP admin (PAY-S3, 2026-05-23 신설)**: `grimoire-server/src/adapter/inbound/http/controller/admin.controller.ts` 3 endpoint — `GET /admin/circuit-breaker/state` (분당 60) / `POST /admin/circuit-breaker/reset` (분당 5) / `POST /admin/circuit-breaker/trip` (분당 5). 모두 `@UseGuards(JwtAuthGuard, AdminGuard)` 강제
- DTO (PAY-S3): `grimoire-server/src/adapter/inbound/http/dto/circuit-breaker.dto.ts` — `CircuitBreakerStateResponseDto`(8 필드 + policy 4값) / `CircuitBreakerActionDto`(key·reason) / `CircuitBreakerActionResponseDto`(success·beforeState·afterState) + `CIRCUIT_BREAKER_KEYS` 화이트리스트 + `toCircuitBreakerStateResponse` 매핑
- admin 영역 spec (PAY-S3): `admin.controller.spec.ts` 신 3 endpoint 7 케이스 + `admin.usecase.spec.ts` 신 3 메서드 4 it
- web (PAY-S3): `grimoire-web/src/app/admin/tabs/components/CircuitBreakerPanel.tsx` (SettingsTab "결제 인프라" sub-section) + `CircuitBreakerPanel.test.tsx` 6 케이스. BFF catchall(`/api/admin/circuit-breaker/*`) 경유, 신 라우트 0

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

### AuditLog 6 action 박제 매트릭스 (PAY-S3 확장)

| action | 영역 | reason 매트릭스 |
|---|---|---|
| `circuit_breaker.open` | CLOSED→OPEN, HALF_OPEN→OPEN, forceOpen | `failure_threshold_exceeded` / `half_open_trial_failed` / `manual_force_open: <reason>` |
| `circuit_breaker.close` | HALF_OPEN→CLOSED, forceClose | `half_open_trial_succeeded` / `manual_force_close: <reason>` |
| `circuit_breaker.half_open_trial` | OPEN→HALF_OPEN | `cooldown_elapsed` |
| `circuit_breaker.reject` | OPEN 호출 차단, HALF_OPEN trial 초과 | `circuit_open` / `half_open_trial_exhausted` |
| **`circuit_breaker.manual_trip`** (PAY-S3) | `admin.controller` POST /trip — 운영자 수동 차단 | operator_id(adminId) + circuitKey + reason + beforeState/afterState (§20 정합) — adapter `open`과 dual박제 (operator 행위 별도 강조) |
| **`circuit_breaker.manual_reset`** (PAY-S3) | `admin.controller` POST /reset — 운영자 수동 복구 | operator_id(adminId) + circuitKey + reason + beforeState/afterState — adapter `close`와 dual박제 |

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
- ~~관리자 UI (forceOpen/forceClose)~~ — **PAY-S3 종료 (2026-05-23)** — port 위에 HTTP admin 3 endpoint + web `CircuitBreakerPanel`(SettingsTab) + AuditLog 신 2 action(`manual_trip`/`manual_reset`) 박제 완료
- 호출 빈도 인벤토리 박제 (운영 모니터링 영역, 잔존)

### 변경 이력
- 2026-05-15 #10_8 PAY-P3-H: 신설 — Polar SDK 호출 경계 가용성 차단 (PAY-P3-B 후속). Hystrix 3 상태 머신 자체 구현 + 사용자 5/15 결정 옵션 B 정합 (failureThreshold=5/cooldownMs=30_000/halfOpenTrial=3/resetWindowMs=60_000). 2 호출점 박제 (checkouts.create + checkouts.list, checkouts.get는 향후). AuditLog 4 action 박제 (open/close/half_open_trial/reject). env 4건. CircuitOpenError 분기 (ServiceUnavailableException 변환 + cron skip). 외부 의존 0건 + DB schema 0건 + dev migration 0건 강제. jest 711 → 735 PASS (+24 it). 정본: `circuit-breaker-state.ts` + `circuit-breaker.port.ts` + `in-memory-circuit-breaker.adapter.ts` + `ADR.md ADR-009`.
- **2026-05-23 PAY-S3: 관리자 UI 박제 — `GET /admin/circuit-breaker/state` + `POST /reset` + `POST /trip` 3 endpoint + DTO 3종 + `CIRCUIT_BREAKER_KEYS` 화이트리스트 + `CircuitBreakerPanel` web 컴포넌트(SettingsTab "결제 인프라" sub-section) + AuditLog 신 2 action(`manual_trip`/`manual_reset`, dual박제 — adapter auto open/close와 병행). 마이그레이션 0건 + env 신설 0건 + 새 시각 정본 신설 0건 + 새 admin 탭 신설 0건. sensor-circuit-breaker-policy 10/10 회귀 0. server jest 1097 → 1108 PASS (+11 it, coverage statements 62.3%) + web vitest 220 → 226 PASS (+6 it). server `5f07305` develop + web `258f3ac`(merge) develop. ADR-009 §"잔존 영역" 4번째 항목("관리자 UI") 단일 닫힘.**

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
  // CC-2b — 案 G1: 응원 선물 양측 작가 1 트랜잭션 이동 (작은 id 먼저 FOR UPDATE + deficit 금지)
  transfer(senderId: string, receiverId: string, amount: number, relatedId?: string):
    Promise<{ senderSpentBySource: Record<CreditSource, number>; receiverGiftBalance: number }>;
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
//   CC-5 (HIGH-1 案 B) — MembershipPlan.tier 가 tier 정본. Author.plan 은 [DEPRECATED] 미러.
export interface MembershipPlanPort {
  getPlan(authorId: string): Promise<MembershipPlanState | null>;  // tier 정본 출처 (案 B)
  resetMonthlyPool(authorId: string, now: Date): Promise<void>;  // 월간 리셋 (이월 금지 — §8-8 #2)
  findPlansToReset(now: Date): Promise<MembershipPlanState[]>;
  // CC-5 — polarSubscriptionId? 추가 (구독 webhook 매핑 저장). status/expiresAt 정합:
  //   free 다운그레이드 → status='cancelled' + expiresAt=now / pro·premium → status='active'.
  changeTier(authorId: string, tier: MembershipTier, now: Date, polarSubscriptionId?: string): Promise<MembershipPlanState>;
  checkAndResetExpiredPool(authorId: string, now: Date): Promise<LazyResetResult>;  // CC-3 lazy 안전망
}

// CC-5 (HIGH-1 案 B) — tier 정본 도메인 헬퍼 (domain/model/membership-tier.ts / plan.ts)
//   getPlan 결과 → tier 결정 / 만기 판정. Author.plan 직접 읽기 0건 — 전부 이 헬퍼 경유.
export function resolveTierOrFree(plan: { tier: string; status: string } | null): MembershipTier;
//   plan null / status!='active' → 'free' 폴백
export function isMembershipExpired(plan: { status: string } | null): boolean;
//   plan null → false(free 만기 없음) / status!='active' → true

// CC-5 (PAY-P1-4) — Polar 구독 생명주기 webhook 정규화 (domain/port/outbound/payment-gateway.port.ts)
//   별도 타입 분리 — 충전 NormalizedWebhookEvent(status 3값)는 구독 생명주기 표현 불가.
export interface NormalizedSubscriptionEvent {
  eventId: string; type: string;
  lifecycle: 'created' | 'updated' | 'canceled' | 'revoked';
  polarSubscriptionId: string;       // MembershipPlan.polarSubscriptionId 매핑 키
  tier: 'free' | 'pro' | 'premium';  // canceled/revoked 시 'free'
  userId?: string;                   // metadata.authorId
}
// verifyAndParseWebhook 반환 = NormalizedWebhookEvent | NormalizedSubscriptionEvent | null.
//   호출자는 isSubscriptionEvent(event) 가드로 라우팅 분기.
export function isSubscriptionEvent(e): e is NormalizedSubscriptionEvent;  // 'lifecycle' in e

// CC-5 (PAY-P1-4) — 구독 정기결제 Checkout (PaymentGatewayPort Optional 메서드)
//   recurring product → Polar 정기결제 모드. env(POLAR_PRODUCT_SUBSCRIPTION_{tier}) 미설정 시 null.
initiateSubscriptionCheckout?(tier: 'pro' | 'premium', userId: string, returnUrl: string):
  Promise<PaymentInitResponse | null>;

// CC-5 (PAY-P1-4) — 구독 webhook usecase (application/subscription/process-subscription-webhook.usecase.ts)
//   created/updated → changeTier(authorId, tier, _, polarSubscriptionId)
//   canceled/revoked → changeTier(authorId, 'free') 다운그레이드. WebhookEvent 멱등성 게이트 재사용.
//   정기결제 갱신 ↔ cron 정합 案 A 분리 — 구독 webhook 은 등급 변경만, 풀 리셋은 resetMonthlyPool cron 단독.

// ClaudeApiPort 확장 — 채팅 사후 차감용 토큰 usage 노출
askWithUsage(systemPrompt: string, userMessage: string, options?: AskOptions): Promise<ClaudeAskResult>;
// ClaudeAskResult: { text, inputTokens, outputTokens, model }

// CREDIT_PRODUCTS — 충전 패키지 4종 (CC-2a 디노미 — domain/model/config.ts)
//   ai-cost-table §2 정본 (cost-accountant 승인 786b0f3 — 전 패키지 §0 PASS).
//   구 3종(credit-5/20/50, credits Int=수량) → 신 4종(points Int=총 pt + bonusRate).
export const CREDIT_PRODUCTS = [
  { id: 'credit-starter', name: '입문 패키지', points: 25000,  bonusRate: 0,    price: 3000,  priceUsd: 299,  providerProductIdEnv: 'POLAR_PRODUCT_STARTER' },
  { id: 'credit-basic',   name: '기본 패키지', points: 41667,  bonusRate: 0,    price: 5000,  priceUsd: 499,  providerProductIdEnv: 'POLAR_PRODUCT_BASIC' },
  { id: 'credit-popular', name: '인기 패키지', points: 91667,  bonusRate: 0.10, price: 10000, priceUsd: 999,  providerProductIdEnv: 'POLAR_PRODUCT_POPULAR' },
  { id: 'credit-best',    name: '베스트 패키지', points: 287500, bonusRate: 0.15, price: 30000, priceUsd: 2999, providerProductIdEnv: 'POLAR_PRODUCT_BEST' },
] as const;
// GET /payments/products 응답: { id, name, points, bonusRate, price, pricePerPoint }

// PaymentRepositoryPort 확장 (CC-2a — domain/port/outbound/payment-repository.port.ts)
//   충전 success 결제 적립 — 案 1 트랜잭션 통합 (헥사고날 DIP 보존, Prisma tx 미노출).
//   CLAUDE.md §9 결제 원자성 — 단일 $transaction: Payment 완료 + deficit 우선 상계
//   (CreditLedger deficit_settle) + 남은 충전액 적립 (CreditLedger source='charged' earn)
//   + Author.pointsCharged/deficitPoints 캐시. 금액 계산은 computeChargeLedgerEntries 위임.
completePaymentWithPoints(
  paymentId: string, authorId: string, totalPoints: number, productId: string, relatedId?: string,
): Promise<{ settledDeficit: number; chargedPoints: number }>;
// 구 completePaymentAtomically(Author.credits Int + CreditLog) 는 @deprecated — CC-2b 후 제거.

// CC-2b — 환불 신 경로 + 이중 외상 통합 (案 R1, completePaymentWithPoints 대칭)
//   단일 $transaction: authors FOR UPDATE + Payment status + 비례 계산(PAY-P2-1)
//   + computeRefundLedgerEntries(charged→gift→subscription→free) + CAS race 차단(PAY-P3-A)
//   + 부족분 Author.deficitPoints 가산 (이중 외상 통합 — RefundLog.deficitCredits 는 감사 추적용)
//   + RefundLog 박제(credits=실 환수 pt, deficitCredits=외상 발생 pt)
refundPaymentWithPoints(input: {
  paymentId: string; authorId: string; refundPt: number;
  refundedAmount: number; reason: string; source: 'webhook' | 'manual'
}): Promise<{ actualRefunded: number; deficitIncurred: number; proportionalPt: number; isPartial: boolean }>;
// 구 refundPaymentAtomically(Author.credits Int + CreditLog) 는 @deprecated — CC-3/CC-4 후 제거.

// computeRefundLedgerEntries (domain/policy/credit-consumption-policy.ts — CC-2b 순수 함수)
//   환수 우선순위 REFUND_RECOVERY_ORDER = ['charged', 'gift', 'subscription', 'free'].
//   4 출처 환수액 + 부족분(=외상 가산분) 반환 — refundPaymentWithPoints + 통합 spec FakeRepo 공통 호출.
computeRefundLedgerEntries(refundPt: number, balances: SourceBalances):
  { recoveredBySource: Record<CreditSource, number>; totalRecovered: number; deficitIncurred: number };

// GIFT_POINT_OPTIONS (domain/model/gift-points.ts — CC-2b 메인 §6 결정)
//   응원 선물 3단계 = 1,000 / 3,000 / 5,000 pt (S Phase §8-6 잠정값 그대로 승인).
//   POST /credits/gift body amount 단위 = pt (디노미 시스템 전체 일관).
export const GIFT_POINT_OPTIONS = [1000, 3000, 5000] as const;

// computeChargeLedgerEntries (domain/policy/credit-consumption-policy.ts — 순수 함수)
//   충전 적립 ledger 박제 계획 — settleDeficitOnCharge 재사용. PaymentRepository 가 호출.
computeChargeLedgerEntries(chargeAmount: number, currentDeficit: number, currentChargedCache: number):
  { settledDeficit: number; remainingCharge: number; remainingDeficit: number; newChargedCache: number };
```

### DB 모델 (Prisma)

- **CreditLedger** (신설) — `authorId` FK Restrict / `source` / `type` / `amount`(부호 有) / `balanceAfter` / `expiresAt?`(구독풀 만료) / `reason` / `relatedId?`. 인덱스 `[authorId,createdAt]` `[authorId,source]` `[expiresAt]`.
- **MembershipPlan** (신설) — `authorId` FK Restrict / `tier`(CC-5 案 B tier 정본) / `monthlyPoolPoints` / `poolBalance` / `poolResetAt` / `polarSubscriptionId?`(CC-5 구독 매핑 — `changeTier` 가 저장) / `status`. 인덱스 `[authorId]` `[poolResetAt]` `[status]`.
- **Author** — 4 필드 추가 (`pointsFree`/`pointsSubscription`/`pointsGift`/`pointsCharged` 잔액 캐시) + `deficitPoints`. `credits` 는 CC-4 Phase 3 DROP 완료. `plan`/`planExpireAt` 은 CC-5 案 B 로 `[DEPRECATED]` (tier 정본 = `MembershipPlan.tier`, `changeTier` 案 A 미러 — 컬럼 물리 DROP 은 별도 후속).

### HTTP 엔드포인트 (CC-5 — PAY-P1-4 구독 정기결제, server 정본 docs/api-contract.md)

- `POST /subscriptions/checkout` — 구독 정기결제 시작. `@UseGuards(JwtAuthGuard)` + `@Throttle`(분당 3). body `{ tier: 'pro'|'premium', returnUrl }` → `{ paymentUrl, tradeNo }`. **graceful** — env(`POLAR_PRODUCT_SUBSCRIPTION_*`) 미설정 시 `503`.
- `GET /membership` — 멤버십 등급/풀 조회. `@UseGuards(JwtAuthGuard)`. → `{ tier, monthlyPoolPoints, poolBalance, poolResetAt, status, expiresAt }`. 내부 ID(`authorId`/`polarSubscriptionId`) 미노출.
- env(Optional) — `POLAR_PRODUCT_SUBSCRIPTION_PRO` / `POLAR_PRODUCT_SUBSCRIPTION_PREMIUM`. 미설정 = 정상 상태(구독 checkout 만 비활성, 나머지 전부 정상).
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
- 2026-05-19 #크레딧개편 CC-1 적립 비결제 연동: grimoire-server — **CRITICAL-2 해소** (I Phase 의 `GrantPointsUseCase` 5메서드 호출처 0건 / 테마 차감 `chargeTheme` 미연동 = 적립 경로 런타임 미작동). 비결제 적립 5경로를 신 `CreditLedger` 원장으로 이행: ① T1 가입 보너스 (`AuthUseCase` email+Google 2 호출처 → `grantSignupBonus`) ② T2 첫 작품 보너스 (`WorkManagementUseCase` → `grantFirstWorkBonus`) ③ T5 관리자 지급 (`AdminUseCase.grantCredits` → `grantManual` + 출처 파라미터) ④ T6 관리자 차감 (`AdminUseCase.deductCredits` → `CreditLedgerPort.spend`, deficit 불가 모드 — 잔액 부족 시 throw) ⑤ 테마 차감 (`GenerateThemeUseCase` 구 `Author.credits -1` → `ChargePointsUseCase.chargeTheme` 590pt 교체 + 구 경로 제거). **인터페이스 변경**: `ChargePointsUseCase.chargeAnalysis` 반환 `void`→`SpendResult` (§5-D 출처별 환불 입력) / `refundAnalysis(authorId, relatedId?, spentBySource?)` 3번째 인자 추가 (출처별 복원, 미전달 시 charged 폴백) / `refundTheme(authorId, relatedId?)` 신설 / `POST /admin/credits/grant` body `source?` 추가. `AdminUseCase.grantCredits`/`deductCredits` 반환 `{credits,log}`→`{balance: CreditBalance}`. **통합 spec 신설** (`credit-grant-integration.spec.ts` — 실 `GrantPointsUseCase`/`ChargePointsUseCase` + 인메모리 `CreditLedgerPort` fake 로 호출 사슬 검증 — CRITICAL-2 가 unit mock 에 가려진 근본 원인 해결, RED 재현 실증). jest 971→991 PASS (+20 it). 커버리지 60.18%. 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §1·§2-2·§5-D·§8. 잔여(CC-2): T3 충전 / T4 선물 / T7 환불 적립 — 구 경로 잔존.
- 2026-05-20 #크레딧개편 CC-2a 충전 결제 적립 연동: grimoire-server — **CRITICAL-2 충전분(T3) 해소 + C-6 해소**. ① `PaymentRepositoryPort.completePaymentWithPoints` 신설 (案 1 — 단일 `$transaction`: Payment 완료 + deficit 우선 상계 + 충전 적립 `CreditLedger` charged earn + `Author.pointsCharged`/`deficitPoints` 캐시. 案 2 CreditLedgerPort tx 오버로드는 헥사고날 DIP 위반이라 미채택). ② `payment.usecase` 충전 success 분기 재배선 — 구 `completePaymentAtomically` → `completePaymentWithPoints`. `settleDeficit` 가 실 충전 경로에 처음 연결돼 **C-6 해소** (deficit 10,000pt 상한 작가가 충전하면 외상 상계 → `isChatBlocked=false`). ③ 도메인 순수 함수 `computeChargeLedgerEntries` 추출 (案 1 로직 중복 0건). ④ `CREDIT_PRODUCTS` 디노미 4종 개편 (구 credit-5/20/50 `credits` Int=수량 → 신 입문/기본/인기/베스트 `points` Int=총 pt + `bonusRate`. `getProducts` `pricePerCredit`→`pricePerPoint`). ⑤ MEDIUM-4 — `Payment.credits` Int 의미 "수량"→"pt" 재해석 (컬럼 물리 rename 은 CC-2a 범위 외). **인터페이스 변경**: `PaymentRepositoryPort.completePaymentWithPoints` 신설 / `completePaymentAtomically` `@deprecated` / `GET /payments/products` 응답 3종→4종 (`credits`→`points`+`bonusRate`+`pricePerPoint`) / `Author` 도메인 모델에 `pointsFree`/`pointsSubscription`/`pointsGift`/`pointsCharged`/`deficitPoints` 5필드 추가. **통합 spec 신설** (`payment-charge-credit-integration.spec.ts` — 실 `PaymentUseCase` + `FakePaymentRepository`(도메인 헬퍼 실호출) 로 충전 webhook → CreditLedger charged earn + deficit 상계 사슬 검증. C7b RED 재현 실증 — 구 경로로 되돌리면 8건 FAIL). jest 1006→1012 PASS (+6 it 순증, payment.usecase.spec/polar.adapter.spec 디노미 정합 포함). 커버리지 60.37%. cost-accountant 재검증 불요 (`786b0f3` 기존 승인 소비). 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §1-A·§6·§8 + `.claude/state/sprint-cc2a-charge-wiring-plan-draft.md`. 잔여(CC-2b): T4 선물 / T7 환불 적립 — 구 경로 잔존. `Payment.credits` 컬럼 물리 rename / `completePaymentAtomically` 제거 = CC-2b 후.
- 2026-05-20 #크레딧개편 CC-3 이월 금지 lazy 안전망 + Author.plan 양측 동기 + 신 ledger 선물 랭킹: grimoire-server — **잔존 결함 3건(CRITICAL-1·HIGH-1·HIGH-3) 종결**. ① **CRITICAL-1 案 B** — `MembershipPlanPort.checkAndResetExpiredPool(authorId, now): Promise<LazyResetResult>` 신설 (port 추상화, 案 (i)). `credit.usecase.getPointBalance` 가 `ledger.getBalance` 호출 직전에 lazy 훅 호출 — `MembershipPlanPort` Optional DI(BACKWARD COMPATIBLE). 호출 조건: `poolResetAt <= now AND tier !== 'free' AND status === 'active'` (free/미만료/non-active no-op). lazy 실패는 silent log + 잔액 조회 진행 (fallback 안전망). cron(`ResetMonthlyPoolJob`) 1차 + lazy 2차 이중 안전망 — cron 실패해도 잔액 조회 시점에 자동 보정. S Phase draft §8-6 원안 복원 (`reset-monthly-pool.job.ts:18` "I Phase 후속" 후속). ② **HIGH-1 案 A** — `MembershipPlanPort.changeTier` 트랜잭션 안에 `tx.author.update({ data: { plan: tier, planExpireAt } })` 추가. `Author.plan` 정본 유지 + `MembershipPlan.tier` 미러. `planExpireAt` 정책: free → null / pro·premium → poolResetAt 미러. 案 B (`tier` 정본화 + 읽기 13곳 이행)는 CC-3 비대 회피로 미채택 (CC-5/후속 옵션 보존). `changeTier` 호출처 현재 0건 (PAY-P1-4 미착수)이라 案 A 위험 ZERO. ③ **HIGH-3** — `CreditLedgerPort.getGiftRanking(limit): Promise<{authorId, totalGifted}[]>` 신설 (`creditLedger.groupBy(by:['authorId'], where:{source:'gift', type:'earn'}, _sum:{amount}, orderBy:{_sum:{amount:'desc'}}, take:limit)`). `credit.usecase.getGiftRanking`/`getLogs` → `ledger.getGiftRanking`/`ledger.findByAuthor` 위임 (ledger 미주입 시 구 경로 폴백). **인터페이스 변경**: `MembershipPlanPort.checkAndResetExpiredPool` 신설 / `LazyResetResult` 타입 신설 / `CreditLedgerPort.getGiftRanking` 신설 / `CreditUseCase.getLogs` 반환 `CreditLog[]` → `CreditLedgerEntry[] | CreditLog[]` (ledger 주입 시 신 형태) / `GET /credits/logs` 응답 형태 확장 (source/type/balanceAfter/expiresAt/relatedId 추가). **통합 spec 신설** (`credit-rollover-source-ledger-integration.spec.ts` — 실 `CreditUseCase` + 인메모리 `FakeMembershipPlanPort`/`FakeCreditLedger` 로 ① cron 미실행 상태에서 lazy 자동 보정(I1b — 4 시나리오) ② `changeTier` MembershipPlan + Author 양측 동기(I1c) ③ CC-2b 신 선물(`source='gift'`)이 신 ranking 에 집계(I1c — RED 재현: 구 경로면 ranking 누락) ④ `getLogs` `CreditLedgerEntry[]` 반환 검증). jest 1042→1073 PASS (+31 it 순증). 커버리지 61.61%(stmts) / 63.21%(lines) — 게이트 ≥60% 충족. cost-accountant 재검증 불요 (AI 기능 추가 0건, 잔액 조회 lazy 훅 + plan 동기 + 원장 위임만). **결함 3건 종결 증명**: ① `grep checkAndResetExpiredPool src` ≥4건 (port + repository + usecase + spec 4 파일) + 통합 I1b PASS ② `changeTier` 본문 `data: { plan: tier, planExpireAt: newPlanExpireAt }` 박제 + I1c PASS ③ `creditRepo.getGiftRanking`/`findLogsByAuthorId` application 호출 = `credit.usecase` fallback 폴백 경로만(ledger null 가드) + `admin.usecase.findLogsByAuthorId` + `discovery.usecase.getMostGiftedAuthors`(CC-4 후속 sprint 이월 — 진단 §10 호출처) + `ledger.getGiftRanking` 호출처 ≥1건 + I1c PASS. 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §4·§5-A·§5-B·§8 + `.claude/state/sprint-cc3-rollover-source-ledger-plan-draft.md` + ADR-014. CC-3/CC-4 이월: 案 B 이행(읽기 13곳) / `MembershipPlanPort.getPlan` HTTP 노출 / `CreditLog` 테이블 폐기 / `Author.credits` DROP / V Phase 마이그레이션 / sensor 7종 hook 등록(harness 영역).
- 2026-05-21 #크레딧개편 CC-4 Phase 2 Payment.credits → points 물리 rename + RefundLog 案 Y 보존: grimoire-server — Phase 2만(Phase 3 = 별도 sprint). ① **컬럼 물리 rename**: `Payment.credits Int` → `Payment.points Int` (마이그레이션 `20260521_payment_credits_rename_phase2` 1건, `ALTER TABLE "payments" RENAME COLUMN "credits" TO "points"`). Postgres native ALTER — 메타데이터 한정 락, 무손실, 즉시. 역방향 ALTER로 비파괴 롤백. CC-2a 박제 의미(`Payment.credits Int = 충전 총 pt`)를 컬럼명 정합으로 종결 — 신규 개발자 혼선 위험 해소. ② **`PaymentRepositoryPort.PaymentRecord` 인터페이스 변경**: `credits: number` → `points: number`. `create(data: { ..., points: number })`. ③ **RefundLog 案 Y 보존 채택** (planner 권고 정합): `RefundLog.credits Int` + `RefundLog.deficitCredits Int` 컬럼 DDL 변경 0건. 보존 사유 = (a) 명명 충돌 회피(`Author.deficitPoints` 외상 잔액 정본과 의미 충돌 방지) (b) 회귀 범위 최소화(admin/audit 전용, HTTP 미노출) (c) CC-2b 의미 재해석은 schema 주석 + shared-contracts §13 박제로 강화. ④ **응답 키 보존**: `processNormalizedWebhook` 반환 `{ processed, credits, deficitCredits? }` — 외부 호환성(webhook payload) 위해 응답 키 그대로. 내부 컬럼/필드만 rename. ⑤ HTTP 응답 영향 0 — `GET /payments/products` 응답 키 이미 `points`/`pricePerPoint`(CC-2a 박제) / `GET /payments/credits` `bySource.charged`(CC-3 박제) — web 변경 불요. ⑥ 코드 일괄 rename ~30곳 + spec 7 파일. **인터페이스 변경**: `PaymentRecord.credits` → `PaymentRecord.points` / `PaymentRepositoryPort.create` 입력 `credits→points`. jest 1063→1063 PASS(변동 0 — assertion 키만 변경, 신설 it 0). 커버리지 61.74%/63.33%(lines) — 게이트 ≥60% 충족. 빌드 + tsc PASS. 로컬 dev DB migration apply PASS — 사후 검증 SQL 4건 PASS. cost-accountant/visual-canon-keeper 불요(신규 AI 0건, UI 영향 0건). **Payment.points 정합 종결 증명**: `grep "payment\.credits\|Payment\.credits" src --exclude="*.spec.ts"` = 주석 매치 2건만(rename 박제 이력) — 코드 본문 호출 0건 / `payments.points` Postgres 컬럼 존재 + `payments.credits` 컬럼 0건 / `refund_logs.credits`+`deficit_credits` 보존. Phase 3 이월 = `Author.credits` DROP + `CreditLog` 폐기 + `prisma-credit.repository` 잔존 메서드(`findLogsByAuthorId`/`getGiftRanking`) 제거 + `auth.controller:48` 응답 `credits` 필드 제거 + `refund-payment.usecase:124-125` 폴백 정리 + `credit-migration.ts` 디노미 도구 정리 + `prisma-author.repository` Author 매핑 정리. ≥1 sprint 운영 박제 후 별도 sprint(Cursor 반면교사). HIGH-1 案 B = Case C 별도 sprint(사용자 결정 5/21). 정본: `.claude/state/sprint-cc4-phase2-rename-plan-draft.md` + `reports/sprint-cc4-phase2-rename-progress.md`.
- 2026-05-21 #크레딧개편 CC-4 Phase 1 폐기 정리 — 구 메서드 제거 + 신·구 분열 해소: grimoire-server — Phase 1만 (Phase 2/3 = 별도 sprint). ① 구 메서드 시그니처 + 본문 제거: `CreditUseCase.grant`/`.deduct`/`.getBalance` (호출처 0건) + `CreditRepositoryPort.adjustCredits`/`giftTransfer`/`sumNegativeAmounts` (port + repository 본문) + `PaymentRepositoryPort.completePaymentAtomically`/`refundPaymentAtomically` (port + repository 본문). 잔존 = `CreditRepositoryPort.findLogsByAuthorId`/`getGiftRanking` 2종(Phase 3 폐기 예정 — `credit.usecase` 폴백 경로용). ② **신·구 분열 해소**: `CreditLedgerPort.sumSpendByAuthor(authorId?)` 신설 (L2c/L2d) — `CreditLedger.aggregate({_sum, where:{type:'spend'}})` 절대값 반환. `admin.usecase.getStats` `creditRepo.sumNegativeAmounts` → `ledger.sumSpendByAuthor(null)` 전환. `admin.usecase.getAllCreditLogs` `creditRepo.findLogsByAuthorId` → `ledger.findByAuthor(authorId, 100)` 전환. `discovery.usecase.getMostGiftedAuthors` `creditRepo.getGiftRanking` → `creditUseCase.getGiftRanking` 위임 전환(CC-3 ledger 위임 재사용). ③ DI 정리: `AdminUseCase` 생성자 `creditRepo` 인자 제거 / `SocialUseCase` 생성자 `creditRepo` 인자 제거 + 구 `giftTransfer` 폴백 코드 제거 / `DiscoveryUseCase` 생성자 `creditRepo` → `creditUseCase` 전환 / `NovelAnalysisUseCase` 생성자 `creditRepo` 인자 제거 + 구 `adjustCredits` 폴백 제거(`chargePoints` 미주입 시 명시적 BadRequest). ④ `CreditReason` enum 폐기(호출처 0건) — `CreditLedger.reason` 자유 문자열 + 합의된 prefix 규약(`signup_bonus`/`gift_sent:..`/`admin_grant:..`)으로 대체. ⑤ 통합 spec 신설: `credit-rollover-source-ledger-integration.spec.ts` `CC-4 Phase 1 통합 — 구 메서드 제거 + admin·discovery 신·구 분열 해소` describe(4 it — L2c sumSpendByAuthor / L2e findByAuthor / L2a 신 선물 ranking 위임 / port 시그니처 제거 정합). **인터페이스 변경**: `CreditLedgerPort.sumSpendByAuthor(authorId?: string | null): Promise<number>` 신설(절대값 반환) / `AdminUseCase` 생성자 시그니처 `(authorRepo, workRepo, adminRepo, grantPoints, ledger, auditLog)` (creditRepo 제거) / `SocialUseCase` 생성자 시그니처 `(socialRepo, authorRepo, ledger?)` (creditRepo 제거) / `DiscoveryUseCase` 생성자 시그니처 `(authorRepo, workRepo, creditUseCase)` (creditRepo → creditUseCase) / `NovelAnalysisUseCase` 생성자 시그니처에서 `creditRepo` 인자 제거 / `PaymentRepositoryPort` `completePaymentAtomically`/`refundPaymentAtomically` 제거 / `CreditRepositoryPort` `adjustCredits`/`giftTransfer`/`sumNegativeAmounts` 제거 / `CreditUseCase.grant`/`.deduct`/`.getBalance` 제거 (4 메서드만 잔존). jest 1059→1063 PASS (+4 it). 커버리지 61.74%/63.33%(lines) — 게이트 ≥60% 충족. 빌드 + docker build 통과. cost-accountant/visual-canon-keeper 게이트 불요(신규 AI 0건, UI 변경 0건). **구 메서드 제거 증명**: `grep "creditRepo\.\(giftTransfer\|adjustCredits\|sumNegativeAmounts\)\|completePaymentAtomically\|refundPaymentAtomically\|CreditUseCase\.\(grant\|deduct\|getBalance\)\b" src --include="*.ts" --exclude="*.spec.ts"` = 주석만 매치(코드 본문 호출 0건). **신·구 분열 해소 증명**: `grep "creditRepo\." src/application/{admin,discovery}` = 주석 4건만(코드 본문 호출 0건 — 모두 ledger 위임). Phase 2(컬럼 rename `Payment.credits`→`Payment.points`)/Phase 3(`Author.credits` DROP + `CreditLog` 폐기)는 운영 안정성 ≥1 sprint 박제 후 별도 sprint(Cursor 반면교사). 정본: `.claude/state/sprint-cc4-postcleanup-plan-draft.md` (옵션 Z 3 Phase 분할 권고).
- 2026-05-20 #크레딧개편 CC-2b 선물·환불 결제 적립 연동: grimoire-server — **CRITICAL-2 완전 종결** (적립 8경로 中 마지막 T4 선물 + T7 환불 신 시스템 이행). ① `CreditLedgerPort.transfer(senderId, receiverId, amount, relatedId?)` 신설 (案 G1 — 단일 `$transaction`: 데드락 방지 lock 순서 작은 id 먼저 `IN ORDER BY id FOR UPDATE`, sender `planConsumption` 4 출처 차감, **deficit 금지**(외상 선물 불가), receiver `source='gift'` earn + `pointsGift` 가산). ② `credit.usecase.gift` 재배선 — 구 `creditRepo.giftTransfer` → `ledger.transfer`. body `amount` 단위 = **pt**(메인 §6 결정 — 1,000/3,000/5,000pt, `GIFT_POINT_OPTIONS` 도메인 상수 정본). ③ `PaymentRepositoryPort.refundPaymentWithPoints` 신설 (案 R1 — 案 1 대칭): 단일 `$transaction` Payment status + 비례 계산(PAY-P2-1) + `computeRefundLedgerEntries`(charged→gift→subscription→free 우선) + `$executeRawUnsafe` CAS race 차단(PAY-P3-A) + 부족분 `Author.deficitPoints` 가산 + `RefundLog` 박제. ④ **이중 외상 통합** — 외상 정본을 `Author.deficitPoints` 단일화 → CC-2a `completePaymentWithPoints` 가 환불 외상까지 자동 회수(통합 spec C7d로 박제). `RefundLog.deficitCredits` 의미 재해석("이 환불 1건이 유발한 외상 pt 기여분" 감사 추적용, 외상 잔액 정본 아님 — 물리 rename 0건, CC-4 위임). ⑤ 도메인 헬퍼 `computeRefundLedgerEntries` + `REFUND_RECOVERY_ORDER` 추출 (案 R1 로직 중복 0건). ⑥ `refund-payment.usecase.execute` 입력 `credits→refundPt` + 반환 4 필드 rename(`actualDeducted→actualRefunded` 등), `RefundPaymentUseCase` 생성자 `CreditLedgerPort` Optional 추가(beforeState 4 출처 디노미 정합). ⑦ `payment.usecase` cancel 분기 — `refundPaymentUseCase.execute({refundPt: payment.credits, ...})` 호출 정합. **인터페이스 변경**: `CreditLedgerPort.transfer` 신설 / `PaymentRepositoryPort.refundPaymentWithPoints` 신설 / `refundPaymentAtomically` `@deprecated` / `POST /credits/gift` body `amount` 단위 = pt / `RefundLog.credits`·`deficitCredits` 컬럼 의미 재해석(pt 단위). **통합 spec 신설** (`credit-gift-refund-integration.spec.ts` — 실 `CreditUseCase`/`PaymentUseCase`/`RefundPaymentUseCase` + `FakeCreditLedger`/`FakePaymentRepository`(도메인 헬퍼 실호출) 로 C7b 선물 양측 이동 + C7c 4 출처 환수 + **C7d 이중 외상 통합**(환불 외상 → 충전 자동 회수) RED 재현 실증). jest 1012→1042 PASS (+30 it 순증). 커버리지 61.11%(stmts) / 62.67%(lines) — 게이트 ≥60% 충족. cost-accountant 재검증 불요(선물=매출 0, 환불=기존 결제 역방향, 가격값 무변경). **CRITICAL-2 종결 증명**: 적립 8경로(T1~T8) 전부 신 `CreditLedger` — `ledger.transfer` 호출처 1건(`credit.usecase.gift`) + 구 `giftTransfer` application 호출 0건 / `refundPaymentWithPoints` 호출처 1건(`refund-payment.usecase`) + 구 `refundPaymentAtomically` application 호출 0건 + 통합 spec C7b/C7c/C7d PASS. 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §1-B·§1-C·§8 + `.claude/state/sprint-cc2b-gift-refund-wiring-plan-draft.md`. **CC-3 핸드오프 박제**: CC-2b가 선물 적립을 `CreditLedger`로 옮김 → 구 `getGiftRanking`(`CreditLog reason='gift_received'` groupBy) + `getLogs`(`CreditLog.findMany`)가 **신·구 분열** 유발 (새 선물은 `CreditLog` 박제 0건). **CC-3 범위에서 `CreditLedger` 기반 재작성 필수** (HIGH-3 정합 — 진단 §5-B). CC-3/CC-4 이월: 구 메서드(`giftTransfer`/`refundPaymentAtomically`/`completePaymentAtomically`) 제거 + `Author.credits` DROP + `RefundLog.deficitCredits`/`credits` 컬럼 물리 rename.
- 2026-05-21 #크레딧개편 CC-4 Phase 3 — `Author.credits` DROP + `CreditLog` 폐기 + `CreditRepositoryPort` 파일/Port 자체 제거 + 案 P3-Y 옵션 A 응답 키 보존: grimoire-server — **CC-4 sprint 전체 종결 단계**. ① **비가역 마이그레이션 1건**: `prisma/migrations/20260521_author_credits_drop_credit_log_phase3/migration.sql` — `ALTER TABLE "authors" DROP COLUMN "credits"` + `DROP TABLE IF EXISTS "credit_logs" CASCADE` (FK 자동 cascade). 사용자 키워드 게이트 사전 통과(5/21 박제). pg_dump 백업 필수(`pg_dump --table=authors --table=credit_logs`). ② **잔존 코드 제거**: `auth.controller.ts:48` 응답 직렬화 `credits: author.credits` → 案 P3-Y 옵션 A 적용(응답 키 `credits` **보존**, 값 = `creditLedger.getBalance(author.id).total` 매핑, ledger 미주입/throw 시 0 폴백). `AuthController` 생성자 `CreditLedgerPort` Optional DI 추가 + `resolveCredits` 헬퍼 + 5 핸들러(register/login/google/refresh/profile) 매핑. `refund-payment.usecase.ts:115-136` `authorRepo` 폴백(author.credits ?? 0) 완전 제거 → ledger 단일 경로 + 생성자 `authorRepo` 인자 제거. `prisma-author.repository.ts` `updateCredits` 메서드 + `findById`/`findDeletedById`/`findDeletedOlderThan` raw query `credits` 매핑 + `toDomain` 매핑 전부 제거. `domain/model/author.ts` `Author.credits` 필드 제거. `AuthorRepositoryPort.updateCredits` 시그니처 제거. ③ **파일/Port 삭제 4건**: `src/adapter/outbound/persistence/prisma-credit.repository.ts` + `src/domain/port/outbound/credit-repository.port.ts` + `src/domain/model/credit.ts`(CreditLog interface) + `src/domain/model/credit-migration.ts`(+spec — V Phase 마이그레이션 후 1회 사용 도구, 案 P3-d-X). `src/domain/model/index.ts` `./credit` re-export 제거. ④ **DI/usecase 정리**: `app.module.ts` `provide: 'CreditRepositoryPort'` provider 제거. `credit.usecase.ts` 생성자에서 `CreditRepositoryPort` Inject 제거 (3 인자 → 2 인자: authorRepo + ledger? + membershipRepo?). `getGiftRanking`/`getLogs` ledger 미주입 폴백 분기 제거 + ledger Required (미주입 시 BadRequest). `getLogs` 반환 타입 `CreditLedgerEntry[] | CreditLog[]` → `CreditLedgerEntry[]` 단일. ⑤ **Prisma schema 갱신**: `model Author { credits Int }` 컬럼 제거 + `Author.creditLogs CreditLog[]` 관계 제거 + `model CreditLog { ... }` 전체 제거. `prisma format` + `prisma generate` PASS. ⑥ **scripts/ 정리**: `seed-admin.ts`/`seed-all.ts`/`seed-themes.ts`/`seed-more-classics.ts` `credits` create/update 필드 제거. `db-sync.ts` `creditLog.findMany`/`deleteMany`/`create` 루프 제거. ⑦ **응답 키 案 P3-Y-a 보존**: `processNormalizedWebhook` 반환 `{ processed, credits, deficitCredits? }` Phase 2 박제 그대로 유지(외부 호환성 + `webhook-retry.job` consumer 영향 회피). 응답 일관성 정합은 Phase 4/CC-5 별도 sprint. ⑧ **spec 정리**: `credit.usecase.spec.ts` `mockCreditRepo` 제거 + `creditRepo` 인자 제거(3→2 인자) + ledger 미주입 폴백 case → BadRequest case. `refund-payment.usecase.spec.ts` `mockAuthorRepo` 제거 + 4번째 인자 제거 + `balanceBefore 조회 분기 — ledger 미주입 fallback` spec 제거. `credit-gift-refund-integration.spec.ts` + `credit-rollover-source-ledger-integration.spec.ts` `makeCreditRepoMock` 헬퍼 제거 + `new CreditUseCase` 3 인자(creditRepo, authorRepo, ledger) → 2 인자(authorRepo, ledger) + `makeAuthorRepo` `updateCredits` 제거. `prisma-fk-cascade.spec.ts` Restrict 8건 → 7건 정합(CreditLog 제거) + schema.prisma `model CreditLog` 부재 박제 검증 추가. **인터페이스 변경**: `Author.credits` 도메인 model 필드 제거 / `AuthorRepositoryPort.updateCredits` 시그니처 제거 / `CreditRepositoryPort` 인터페이스 자체 제거 / `CreditLog` interface 제거 / `CreditUseCase` 생성자 시그니처 `(creditRepo, authorRepo, ledger?, membershipRepo?)` → `(authorRepo, ledger?, membershipRepo?)` / `CreditUseCase.getLogs` 반환 타입 `CreditLedgerEntry[]` 단일 / `RefundPaymentUseCase` 생성자 시그니처 `(paymentRepo, auditLog, authorRepo?, ledger?)` → `(paymentRepo, auditLog, ledger?)` / `AuthController` 생성자 시그니처 `(authUseCase, accessLog, prisma, creditLedger?)` 추가. **신설 통합 spec describe** (`credit-rollover-source-ledger-integration.spec.ts` `CC-4 Phase 3 — Author.credits 컬럼 + CreditLog 테이블 폐기 정합` 3 it — Author.credits 필드 부재 컴파일 타임 박제 / CreditRepositoryPort interface 부재 박제 / 4 출처 잔액 단일 정본 회귀 안전망). jest 1051→1054 PASS (+3 it). 커버리지 61.66%(stmts) / 63.23%(lines) — 게이트 ≥60% 충족. 빌드 + tsc PASS. **로컬 dev DB migration apply PASS** — 사후 검증 SQL 4건 + Phase 2 정합 회귀 1건 = 5건 PASS(`authors.credits` 컬럼 부재 0 rows / `credit_logs` 테이블 부재 0 rows / 신 4 출처+deficit 컬럼 5건 정합 / migration history finished_at NOT NULL / Phase 2 `payments.points` 정합 회귀 0건). cost-accountant/visual-canon-keeper 게이트 불요(신규 AI 0건, UI 변경 0건 — 案 P3-Y 옵션 A 보존 정합). **DROP 증명**: `grep -rn "\.credits\b" src --include="*.ts" --exclude="*.spec.ts" \| grep -v "//\|/\*"` = 코드 본문 0건(주석/박제만 잔존) / `ls src/adapter/outbound/persistence/prisma-credit.repository.ts` = No such file / `ls src/domain/port/outbound/credit-repository.port.ts` = No such file / `ls src/domain/model/credit.ts` = No such file / `ls src/domain/model/credit-migration.ts` = No such file. **CC-4 sprint 전체 종결 박제**: Phase 1(구 메서드 제거) + Phase 2(Payment.credits→points rename) + Phase 3(Author.credits DROP + CreditLog 폐기) = 크레딧 디노미네이션 + 4 출처 회계 시스템 단일 정본 종결. dev/prod migration apply는 grimoire-infrastructure agent 영역(별도 핸드오프). web 핸드오프 = data-model.md + api-contract.md sync only(코드 변경 0건 — 案 P3-Y 옵션 A 보존). HIGH-1 案 B = Case C(별도 sprint, 사용자 결정 5/21 박제) + CC-5 PAY-P1-4 Polar 구독 연동(별도 sprint) + Phase 4 응답 일관성 정합(`processNormalizedWebhook` 반환 키 정합, 외부 호환성 영향 평가 종속, 별도 sprint). 정본: `.claude/state/sprint-cc4-phase3-drop-plan-draft.md` + `reports/sprint-cc4-phase3-drop-progress.md`.
- 2026-05-22 #크레딧개편 CC-5 Polar 구독 정기결제 연동 + HIGH-1 案 B: grimoire-server — **PAY-P1-4 종결 + HIGH-1 案 B 이행** (코드 구현만 — Polar 구독 상품 실등록 / 배포 / priceUsd cost-accountant 게이트 범위 외, 메인 후속). **Phase A — HIGH-1 案 B (`MembershipPlan.tier` 정본화)**: ADR-014 案 A → 案 B 전환. ① `resolveTierOrFree(membership-tier.ts)` + `isMembershipExpired(plan.ts)` 도메인 헬퍼 신설 — `getPlan` 결과 → tier 결정 / 만기 판정(plan null·status!='active' → free). ② theme 도메인 11곳 이행 — `generate-theme`/`theme-slot`/`get-theme` 의 `Author.plan` 직접 읽기를 `MembershipPlanPort.getPlan` + `resolveTierOrFree`/`isMembershipExpired` 경유로 교체. `MEMBERSHIP_THEME_SLOTS`/`MEMBERSHIP_DAILY_FREE_THEME` 사용. `MembershipPlanPort` Optional DI. ③ `plan.usecase`/`admin.usecase` — `activatePlan`/`createAuthor`/`changePlan` 의 직접 `authorRepo.updatePlan` SQL → `MembershipPlanPort.changeTier` 단일 진입점. ④ `Author.plan`/`planExpireAt` `[DEPRECATED]` 박제 (tier 정본 = `MembershipPlan.tier`, `changeTier` 案 A 미러 유지 — 컬럼 물리 DROP 은 별도 후속). **Phase B — Polar 구독 webhook**: ⑤ `NormalizedSubscriptionEvent` 신 타입 + `isSubscriptionEvent` 가드 (충전 `NormalizedWebhookEvent` status 3값이 구독 생명주기 표현 불가 — 타입 분리). ⑥ `polar.adapter` webhook 화이트리스트 — `subscription.created/updated/canceled/revoked` 4 case + `parseSubscriptionEvent` 정규화 + `tierForSubscriptionProductId`(productId→tier 역매핑) + metadata 폴백. ⑦ `ProcessSubscriptionWebhookUseCase` 신설 — created/updated → `changeTier(tier)` + `polarSubscriptionId` 매핑, canceled/revoked → `changeTier('free')` 다운그레이드. `WebhookEvent` 멱등성 게이트 재사용. ⑧ `changeTier` 시그니처 4번째 인자 `polarSubscriptionId?` + status/expiresAt 정합(free 다운그레이드 → cancelled, pro/premium → active). ⑨ `payment.usecase.processWebhook` 에 `isSubscriptionEvent` 라우팅 분기. ⑩ 정기결제 갱신↔cron 정합 案 A 분리 — 구독 webhook 은 등급 변경만, 풀 리셋은 `resetMonthlyPool` cron 단독. **Phase C — HTTP 엔드포인트**: ⑪ `polar.adapter.initiateSubscriptionCheckout` + `resolveSubscriptionProductId` (recurring product, CircuitBreaker 래핑). ⑫ `StartSubscriptionUseCase`/`GetMembershipUseCase` 신설. ⑬ `SubscriptionController` — `POST /subscriptions/checkout`(`JwtAuthGuard` + `@Throttle` 분당 3) + `GET /membership`(`JwtAuthGuard`). DTO class-validator. 내부 ID 미노출(SECURITY.md §4). **graceful 설계** (사용자 핵심 요건): env `POLAR_PRODUCT_SUBSCRIPTION_PRO/_PREMIUM` Optional — 미설정 시 `POST /subscriptions/checkout` 만 503, webhook 수신·`GET /membership`·기존 충전·테마·분석 전부 정상. **인터페이스 변경**: `MembershipPlanPort.changeTier` 4번째 인자 `polarSubscriptionId?` 추가 / `NormalizedSubscriptionEvent` 타입 신설 / `isSubscriptionEvent` 가드 신설 / `verifyAndParseWebhook` 반환 `NormalizedWebhookEvent | NormalizedSubscriptionEvent | null` / `PaymentGatewayPort.initiateSubscriptionCheckout?` Optional 메서드 신설 / `resolveTierOrFree`·`isMembershipExpired` 도메인 헬퍼 신설 / `POST /subscriptions/checkout`·`GET /membership` 신규 엔드포인트 / theme/plan/admin usecase 생성자에 `MembershipPlanPort` Optional 인자 추가 / `AdminUseCase` 생성자 7번째 인자 `MembershipPlanPort?`. **통합 spec 신설** (`subscription-webhook-integration.spec.ts` — 실 `ProcessSubscriptionWebhookUseCase`/`GetMembershipUseCase`/`StartSubscriptionUseCase`/`ThemeSlotUseCase` + 인메모리 fake 로 ① 구독 webhook → changeTier → MembershipPlan.tier 갱신 + polarSubscriptionId 저장 ② `GET /membership` 갱신 tier 반환 ③ revoke → free 다운그레이드 ④ 案 B 정합 — 구독 후 theme-slot 새 tier 슬롯 ⑤ graceful env 미설정 503 ⑥ 멱등성 중복 webhook → changeTier 1회 ⑦ 정기결제↔cron 정합 案 A 분리). jest 1054→1094 PASS (+40 it). 커버리지 61.92%(stmts) / 63.45%(lines) — 게이트 ≥60% 충족. 빌드 PASS. **마이그레이션 0건** — `Author.plan` 案 B 는 deprecated 주석만(컬럼 물리 변경 0), `MembershipPlan.polarSubscriptionId` 필드는 I Phase 부터 존재. cost-accountant 게이트 = priceUsd 1건(범위 외 — 메인 후속), visual-canon-keeper 불요(server sprint). **PAY-P1-4 종결 증명**: `grep "subscription.created" src/adapter/outbound/payment` ≥1건(화이트리스트) + `changeTier` 호출처 `process-subscription-webhook.usecase` 1건 + 통합 spec ① PASS. **HIGH-1 案 B 증명**: `grep "author\.plan\b" src/application/theme src/application/plan`(직접 읽기) 0건(getPlan 경유) + `Author.plan` `[DEPRECATED]` 박제 + 통합 spec ④ PASS. 잔존(메인 후속): Polar 구독 상품 dev/prod 등록 + env 입력 / priceUsd cost-accountant 게이트 / web 구독 페이지 실연결(별도 web sprint) / `Author.plan` 컬럼 물리 DROP(별도 후속). 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §7·§5-A + `.claude/state/sprint-cc5-subscription-plan-draft.md` + `reports/sprint-cc5-subscription-progress.md` + ADR-015.

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
