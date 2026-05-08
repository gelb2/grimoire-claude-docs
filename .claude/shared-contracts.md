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
