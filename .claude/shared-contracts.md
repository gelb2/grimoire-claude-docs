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
- 2026-05-03 #10_7 PAY-P0-2: 신설 — PG↔DB 정합성 검증 cron (CERTI_PROJ thermage-batch-api `@Cron('*/10 * * * * *')` 패턴 차용 + Grimoire 10분 주기 완화). cost-accountant Polar `/v1` rate limit 사용률 1% PASS, §0 면제.

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
