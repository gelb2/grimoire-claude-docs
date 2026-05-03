# Sprint Progress — pay-p0-1-webhook-event-id-idempotency

> **Sprint ID**: sprint-pay-p0-1-webhook-event-id-idempotency
> **세션**: #10_7 PAY-P0-1 (PAYMENT_SYSTEM_PLAN §3-1 첫 항목)
> **Initializer**: grimoire-planner (책 Ch 16 Anthropic 3-에이전트 패턴 — 묶음 II 3회차)
> **작성일**: 2026-05-03
> **단일 진실**: 본 파일이 Generator (server / claude-docs) + Evaluator (qa) 모두의 작업 정본. 모호하면 본 파일 갱신 후 합의.

---

## 0. Goal — 한 줄

Polar webhook 재전송 시 동일 `eventId`로 두 번째 호출이 들어와도 `completePaymentAtomically`가 **단 1회만 실행**되도록 DB 멱등성 테이블 (`WebhookEvent`) 신설 + `processWebhook` 게이트 추가. **돈은 냈는데 크레딧 두 번 들어가는 사고 0건** 보장.

---

## 1. 배경 (메인 사전 파악 — 실측 박제)

### 1-1. 현재 멱등성 약식 (PAYMENT_SYSTEM_PLAN §1-3 step 6 재인용)

`grimoire-server/src/application/payment/payment.usecase.ts:42~59` 현재 코드:

```typescript
async processWebhook(rawBody, headers) {
  const event = this.paymentGateway.verifyAndParseWebhook(rawBody, headers)
  if (!event) return { processed: false, reason: 'invalid_or_ignored' }

  const payment = await this.paymentRepo.findByExternalTransactionId(event.tradeNo)
  if (!payment) return { processed: false, reason: 'unknown_trade' }
  if (payment.status === 'completed') return { processed: false, reason: 'already_completed' }  // ← 약식 멱등성

  if (event.status === 'success') {
    await this.paymentRepo.completePaymentAtomically(...)
  }
}
```

**갭**: `payment.status === 'completed'` 체크는 "같은 payment에 대한 중복 처리"는 막지만, **다른 이벤트 타입 (order.paid → order.refunded → order.paid 재시도)** 또는 **Polar 측 webhook 재전송 큐**가 동일 eventId로 빠르게 두 번 보내는 경우에 race condition 가능 (DB 트랜잭션 commit 직전에 두 번째 webhook 진입 시 둘 다 status='pending' 본다).

### 1-2. NormalizedWebhookEvent 인터페이스 — eventId 필드 부재 실측

`grimoire-server/src/domain/port/outbound/payment-gateway.port.ts:29~40`:

```typescript
export interface NormalizedWebhookEvent {
  type: string         // 'order.paid' / 'order.refunded' / ...
  tradeNo: string      // checkoutId
  amount: number
  status: 'success' | 'fail' | 'cancel'
  userId?: string
  // ❌ eventId 필드 부재 — 추가 필수
}
```

### 1-3. Polar Standard Webhooks 스펙 (확정)

- `webhook-id` 헤더 — Polar가 발급하는 unique event ID (UUID 또는 고유 문자열)
- `webhook-timestamp` — Unix timestamp
- `webhook-signature` — HMAC

`polar.adapter.ts:113~124`에서 `validateEvent(body, headers, this.webhookSecret)` 호출 시 헤더는 그대로 보유. `headers['webhook-id']`로 추출 가능.

### 1-4. DB 모델 — WebhookEvent 신설 위치

`grimoire-server/prisma/schema.prisma:192~204` `Payment` 모델 뒤. 마이그레이션 명: `{YYYYMMDDHHMMSS}_add_webhook_event_idempotency`.

---

## 2. Scope

### 2-1. IN

| 항목 | 영역 | 파일 (예상 경로) |
|---|---|---|
| Prisma 모델 `WebhookEvent` | server | `grimoire-server/prisma/schema.prisma` |
| 마이그레이션 SQL | server | `grimoire-server/prisma/migrations/{ts}_add_webhook_event_idempotency/migration.sql` |
| `NormalizedWebhookEvent.eventId` 필드 추가 | server | `grimoire-server/src/domain/port/outbound/payment-gateway.port.ts` |
| `polar.adapter.verifyAndParseWebhook` — `headers['webhook-id']` 추출 | server | `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts:100~186` |
| `WebhookEventRepositoryPort` 신설 | server | `grimoire-server/src/domain/port/outbound/webhook-event-repository.port.ts` (신설) |
| Prisma 어댑터 구현 | server | `grimoire-server/src/adapter/outbound/persistence/prisma-webhook-event.repository.ts` (신설) |
| `payment.usecase.processWebhook` 게이트 | server | `grimoire-server/src/application/payment/payment.usecase.ts:42~59` |
| Spec 검증 (재진입 → 1회만 실행) | server | `grimoire-server/src/application/payment/payment.usecase.spec.ts` (확장) |
| `app.module.ts` DI 바인딩 | server | `grimoire-server/src/app.module.ts` |
| sensor 신설 | claude-docs | `.claude/scripts/sensor-payment-idempotency.sh` |
| `sensor-adversarial-pre-commit` P16 연동 | claude-docs | `.claude/scripts/sensor-adversarial-pre-commit.sh` (Principle 16 강화) |
| shared-contracts §11 신설 | claude-docs | `.claude/shared-contracts.md` |
| 정본 문서 | server | `docs/api-contract.md` (webhook 멱등성 명시) + `docs/data-model.md` (WebhookEvent 모델) + `SCHEMA.md` + `MIGRATION.md` + `TECH_STATUS.md` |
| eval regression | claude-docs | `eval/tasks/regression-52-webhook-event-id-idempotency.json` |

### 2-2. OUT

- **PG↔DB 정합성 검증 batch** (PAY-P0-2 — 별도 Sprint)
- **운영자 수동 지급 web UI** (PAY-P0-3 — 별도 Sprint)
- **WebhookEvent 모델 retention 정책** (90일 이후 archive 등 — PAY-P1)
- **다른 PG 어댑터 통합 멱등성** (현재 Polar 단독 → 추후 PaymentGatewayPort 차원 확장)
- **PROD 데이터 마이그레이션** (PROD에 기존 `payments` 데이터는 그대로 둠 — 신규 webhook부터 적용)
- **server 외 레포 (web)** — 본 Sprint는 100% server + claude-docs (web 변경 0건. 실측 ≥0 보장.)

---

## 3. 결정 사항 (Initializer 최종)

### 3-1. 방향 결정

| 방향 | 채택 | 사유 |
|---|---|---|
| **A. WebhookEvent 테이블 신설 (eventId @unique)** | ✅ **채택** | DB unique 제약으로 race condition 원천 차단. 책 Ch 16 "shared state via DB" 정합. |
| B. Redis SETNX with TTL | ❌ 기각 | Redis 인프라 미도입 (Azure Container Apps 단일 컨테이너). 추가 비용 발생. |
| C. 메모리 LRU cache | ❌ 기각 | replicas ≥2일 때 정합성 깨짐. 컨테이너 재시작 시 cache 손실. |
| D. application 레벨 lock (advisory_lock) | ❌ 기각 | PostgreSQL advisory_lock 복잡도 + 디버깅 난이도 ↑. WebhookEvent 테이블 + unique 제약이 더 단순. |

### 3-2. WebhookEvent 모델 (정본)

```prisma
model WebhookEvent {
  id             String    @id @default(uuid())
  eventId        String    @unique @map("event_id")          // Polar webhook-id 헤더 박제
  source         String    @default("polar")                  // PG 식별 ('polar' / 향후 다른 PG)
  eventType      String    @map("event_type")                 // 'order.paid' / 'order.refunded' / ...
  payload        Json                                         // 정규화된 NormalizedWebhookEvent 박제 (디버깅용)
  status         String                                       // 'processed' / 'skipped' / 'failed'
  errorMessage   String?   @map("error_message")              // 실패 시 사유
  processedAt    DateTime  @default(now()) @map("processed_at") @db.Timestamptz(3)

  @@index([eventType, processedAt])
  @@map("webhook_events")
}
```

### 3-3. processWebhook 새 게이트 흐름

```
1. verifyAndParseWebhook → event { eventId, type, tradeNo, ... }
2. eventId 없으면 (Polar webhook-id 헤더 부재) → 보안 fallback: status='failed' 박제 후 401
3. webhookEventRepo.findByEventId(event.eventId)
   3-a. 발견 → 200 OK + reason='duplicate_event' 즉시 반환 (skip, completePaymentAtomically 0회)
   3-b. 미발견 → 4 진행
4. 기존 로직 (findByExternalTransactionId / completePaymentAtomically)
5. **마지막에** webhookEventRepo.create({eventId, source:'polar', eventType, payload, status})
   - status='processed' (성공) / 'skipped' (already_completed) / 'failed' (예외)
6. 동시 진입 race: WebhookEvent.eventId @unique 제약이 두 번째 INSERT 거부 (P2002 catch → 'duplicate_event')
```

**핵심**: step 5 INSERT 시 `@unique` 제약 위반 (Prisma `P2002`)을 잡아서 두 번째 호출을 안전하게 무시. 첫 호출만 `completePaymentAtomically` 실행 보장.

### 3-4. WebhookEventRepositoryPort 시그니처

```typescript
export interface WebhookEventRecord {
  id: string
  eventId: string
  source: string
  eventType: string
  payload: unknown
  status: 'processed' | 'skipped' | 'failed'
  errorMessage: string | null
  processedAt: Date
}

export interface WebhookEventRepositoryPort {
  findByEventId(eventId: string): Promise<WebhookEventRecord | null>
  create(data: {
    eventId: string
    source: string
    eventType: string
    payload: unknown
    status: 'processed' | 'skipped' | 'failed'
    errorMessage?: string
  }): Promise<WebhookEventRecord>
  /**
   * Race condition 안전 INSERT — eventId @unique 위반 시 null 반환 (이미 처리됨).
   * Prisma P2002 코드 catch.
   */
  createIfAbsent(data: {
    eventId: string
    source: string
    eventType: string
    payload: unknown
    status: 'processed' | 'skipped' | 'failed'
    errorMessage?: string
  }): Promise<WebhookEventRecord | null>
}
```

---

## 4. Acceptance Criteria (AC) — 7건, Ambiguity ≤ 0.1

각 AC는 **실측 검증 가능한 raw stdout / grep 결과**로 증명. Generator는 본 AC를 충족하지 못하면 작업 미완료 박제 (DEV_REPORT.md에 raw stdout 박제).

### AC-1: WebhookEvent DB 모델 신설 + 마이그레이션 적용 (localhost 실측)

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
grep -A 13 'model WebhookEvent' prisma/schema.prisma
ls prisma/migrations/ | grep webhook_event_idempotency
npx prisma migrate status   # localhost — "Database schema is up to date" 출력 박제
psql $DATABASE_URL -c "\d webhook_events"   # 테이블 + 인덱스 + unique 제약 확인
```

**기대 raw 출력**:
- `model WebhookEvent` 블록 존재 + `eventId String @unique` 명시
- 마이그레이션 디렉토리 1건 (`{ts}_add_webhook_event_idempotency`)
- `prisma migrate status` 결과 "Database schema is up to date" or 동등 메시지
- `\d webhook_events` 결과 `event_id` 컬럼 + `webhook_events_event_id_key` UNIQUE 인덱스 박제

### AC-2: NormalizedWebhookEvent.eventId 필드 추가 + polar.adapter `webhook-id` 헤더 추출

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
grep -nE '^\s*eventId\s*:\s*string' src/domain/port/outbound/payment-gateway.port.ts
grep -n "headers\['webhook-id'\]\|headers\[\"webhook-id\"\]" src/adapter/outbound/payment/polar.adapter.ts
npx tsc --noEmit 2>&1 | grep -c 'error TS' | xargs -I{} test {} -eq 0   # 0 errors
```

**기대 raw 출력**:
- `payment-gateway.port.ts`에 `eventId: string` 필드 1건 (NormalizedWebhookEvent 인터페이스 내부)
- `polar.adapter.ts`에 `headers['webhook-id']` 또는 `headers["webhook-id"]` 1건 이상
- `tsc --noEmit` 0 errors

### AC-3: payment.usecase.processWebhook이 findByEventId 먼저 검색 → duplicate_event skip

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
grep -n "findByEventId\|webhookEventRepo" src/application/payment/payment.usecase.ts
grep -n "duplicate_event" src/application/payment/payment.usecase.ts
```

**기대 raw 출력**:
- `payment.usecase.ts`에 `webhookEventRepo.findByEventId(event.eventId)` 호출 1건 이상
- 같은 파일에 `'duplicate_event'` 또는 `"duplicate_event"` reason 박제 1건 이상
- 호출 순서가 `findByExternalTransactionId`보다 먼저 (sed로 라인 번호 비교: `findByEventId` 라인 < `findByExternalTransactionId` 라인)

### AC-4: 같은 eventId로 webhook 두 번 호출 → 첫 호출만 completePaymentAtomically (jest spec)

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
grep -nE 'duplicate event|동일.*event.*두 번|webhook 재전송|중복 webhook' src/application/payment/payment.usecase.spec.ts
npm test -- payment.usecase 2>&1 | tail -30
```

**기대 raw 출력**:
- `payment.usecase.spec.ts`에 신규 it 블록 1건 이상 (예: `'동일 eventId로 두 번 호출 시 첫 호출만 completePaymentAtomically 실행한다'`)
- 해당 spec 내부에서 `mockWebhookEventRepo.findByEventId`를 1번째 호출은 null, 2번째 호출은 기존 record 반환하도록 mock
- `expect(mockPaymentRepo.completePaymentAtomically).toHaveBeenCalledTimes(1)` 박제
- npm test 결과 신규 spec 포함 PASS, 기존 spec 회귀 0건

### AC-5: 새 sensor `sensor-payment-idempotency.sh` 신설 + adversarial-pre-commit P16 연동

**검증 명령**:
```bash
ls /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-payment-idempotency.sh
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-payment-idempotency.sh
echo "exit code: $?"
grep -n "sensor-payment-idempotency\|webhook event id\|멱등성" /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-adversarial-pre-commit.sh
```

**기대 raw 출력**:
- 파일 존재 + chmod +x
- 직접 실행 시 PASS (exit 0) — 검증 항목 ≥4건:
  1. `WebhookEvent` 모델 schema.prisma 박제
  2. `NormalizedWebhookEvent.eventId` 인터페이스 필드 박제
  3. `payment.usecase.ts`에 `findByEventId` 호출
  4. polar.adapter가 `webhook-id` 헤더 추출
- adversarial-pre-commit Principle 16에서 본 sensor 호출 또는 동등한 멱등성 게이트 박제

### AC-6: shared-contracts §11 WebhookEventIdempotency 인터페이스 박제

**검증 명령**:
```bash
grep -nE '^## 11\..*WebhookEvent|^### 11-' /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/shared-contracts.md
grep -n 'WebhookEventRepositoryPort\|eventId.*@unique\|findByEventId' /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/shared-contracts.md
```

**기대 raw 출력**:
- §11 섹션 헤더 신설 (`## 11. WebhookEventIdempotency` 또는 동등)
- `WebhookEventRepositoryPort` 시그니처 박제 (createIfAbsent 포함)
- `eventId @unique` 정책 명시
- 변경 이력 1줄: `2026-05-03 PAY-P0-1: WebhookEventIdempotency 인터페이스 신설`

### AC-7: regression-52 신설 + eval 51→52 PASS

**검증 명령**:
```bash
cat /Users/sokol/Desktop/Git/ProjectGrimoire/eval/tasks/regression-52-webhook-event-id-idempotency.json
ls /Users/sokol/Desktop/Git/ProjectGrimoire/eval/tasks/regression-*.json | wc -l
bash /Users/sokol/Desktop/Git/ProjectGrimoire/eval/scripts/eval-runner.sh 2>&1 | tail -10
```

**기대 raw 출력**:
- regression-52 JSON 존재 + eval_criteria ≥5건 (위 AC-1~5 grep 명령 박제)
- `ls regression-*.json | wc -l` 결과 52 (현재 51)
- eval-runner stdout 마지막 행: `regression: 52/52 PASS (100%)` 또는 동등

---

## 5. Test Plan

### 5-1. 단위 테스트 (jest)

| spec 파일 | 신규 it 블록 |
|---|---|
| `payment.usecase.spec.ts` | (a) 동일 eventId 재호출 시 첫 호출만 completePaymentAtomically (b) eventId 없는 webhook → status='failed' 박제 (c) WebhookEvent.create P2002 race → 안전 skip |
| `polar.adapter.spec.ts` (있을 시 또는 신설) | `headers['webhook-id']`가 NormalizedWebhookEvent.eventId로 박제되는지 |
| `prisma-webhook-event.repository.spec.ts` (신설) | findByEventId / createIfAbsent (P2002 catch → null) |

### 5-2. 통합 테스트 — 수동 (localhost)

`reports/sprint-pay-p0-1-webhook-event-id-idempotency-progress.md` Generator 단계에서:
1. localhost server 부팅 → ngrok 또는 직접 curl로 webhook 더미 페이로드 두 번 전송
2. 첫 호출: status=200, reason='processed'
3. 두 번째 호출: status=200, reason='duplicate_event'
4. DB 검사: `payments.status='completed'` 1건 / `webhook_events` 1건 / `Author.credits` +N (이중 부여 0건)

**raw 박제 위치**: DEV_REPORT.md Server 섹션 §3 구현 결과 + §5 sensor 결과 (curl stdout + psql SELECT 결과 전문)

### 5-3. sensor 회귀

- `sensor-credit-atomicity` PASS 유지 (FAIL 회귀 시 즉시 차단)
- `sensor-shared-contracts` drift 0 (§11 신설로 mtime 갱신)
- `sensor-server` PASS (npm test + tsc 0 errors)
- `sensor-docs-sync` PASS (data-model.md + SCHEMA.md 같은 commit)
- `sensor-adversarial-pre-commit` Principle 16 강화 후 PASS (false positive 1건 해소 보너스)
- `sensor-payment-idempotency` (신설) PASS

### 5-4. eval 회귀

- regression-52 (본 Sprint 신설)
- regression 51→52 / EDD 21~33 모두 PASS (drift 0)

---

## 6. 검증 게이트 (Generator → Evaluator 핸드오프 전 필수 통과)

### 6-1. server 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G1 | TypeScript | `npx tsc --noEmit` | 0 errors |
| G2 | Lint | `npm run lint` | 0 errors |
| G3 | npm test (전체) | `npm test 2>&1 \| tail -20` | 모든 spec PASS, 회귀 0건 |
| G4 | Prisma migrate | `npx prisma migrate status` | "Database schema is up to date" |
| G5 | Prisma validate | `npx prisma validate` | 0 errors |
| G6 | Build | `npm run build` | 0 errors |

### 6-2. claude-docs 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G7 | sensor 5종 | `for s in sensor-shared-contracts sensor-server sensor-docs-sync sensor-credit-atomicity sensor-payment-idempotency sensor-adversarial-pre-commit; do bash .claude/scripts/$s.sh; done` | 모두 exit 0 (PASS) |
| G8 | eval | `bash eval/scripts/eval-runner.sh` | regression 52/52 PASS, drift 0 |

### 6-3. Evaluator (qa) 채점 항목

- AC 7건 각각 PASS/FAIL 판정 (raw stdout 박제)
- DEV_REPORT.md `Server 섹션 §5 센서 결과` raw stdout 전문 박제 여부
- QA_REPORT.md `### sprint-pay-p0-1-webhook-event-id-idempotency 통과율` 박제 (목표 7/7 = 100%)
- dev 환경 배포 후 webhook 멱등성 수동 검증 (curl 두 번)

---

## 7. 산출물 체크리스트

### 7-1. server 산출물

- [x] `prisma/schema.prisma` — WebhookEvent 모델 추가 (2026-05-03 #10_7)
- [x] `prisma/migrations/20260503143403_add_webhook_event_idempotency/migration.sql` — 신설 + localhost 적용
- [x] `src/domain/port/outbound/payment-gateway.port.ts` — eventId 필드 추가
- [x] `src/domain/port/outbound/webhook-event-repository.port.ts` — 신설
- [x] `src/adapter/outbound/persistence/prisma-webhook-event.repository.ts` — 신설 (P2002 catch)
- [x] `src/adapter/outbound/persistence/prisma-webhook-event.repository.spec.ts` — 신설 (8 it)
- [x] `src/adapter/outbound/payment/polar.adapter.ts` — `webhook-id` 헤더 추출 + 누락 시 null 반환
- [x] `src/application/payment/payment.usecase.ts` — findByEventId 게이트 + 마지막 createIfAbsent
- [x] `src/application/payment/payment.usecase.spec.ts` — 신규 it 4건 (PAY-P0-1 describe 블록)
- [x] `src/app.module.ts` — WebhookEventRepositoryPort DI 바인딩
- [x] `docs/api-contract.md` — POST /api/payments/webhook 멱등성 정책 박제 (`duplicate_event` reason 신규)
- [x] `docs/data-model.md` — WebhookEvent 모델 섹션 신설 (테이블 21 → 22)
- [x] `SCHEMA.md` — WebhookEvent Prisma 매핑 + 관계 다이어그램 박제
- [x] `MIGRATION.md` §7-AA — 신규 마이그레이션 절차 + 롤백 정책 박제
- [x] `TECH_STATUS.md` — PAY-P0-1 완료 박제
- [x] `CHANGELOG.md` — v0.31.0 박제
- [x] DEV_REPORT.md Server 섹션 — raw stdout (npm test + tsc + prisma migrate status + psql) 전문 박제

### 7-2. claude-docs 산출물

- [ ] `.claude/scripts/sensor-payment-idempotency.sh` — 신설 (chmod +x)
- [ ] `.claude/scripts/sensor-adversarial-pre-commit.sh` — Principle 16 강화 (본 sensor 호출)
- [ ] `.claude/shared-contracts.md` §11 — WebhookEventIdempotency 인터페이스 신설
- [ ] `eval/tasks/regression-52-webhook-event-id-idempotency.json` — 신설 (eval_criteria ≥5건)
- [ ] PLANNING_GRIMOIRE.md — PAY-P0-1 완료 마크 (사용자 승인 필요 — Initializer는 권고만)

### 7-3. server 변경 없음 (web)

- 본 Sprint는 100% server 백엔드 영역 (web 화면 변경 0건). 단, web의 `dashboard/credits/page.tsx` 등은 webhook 결과를 polling으로 받으므로 시각/플로우 변경 없음. Generator는 web 레포 touch 0건 박제 (실측 git diff 0).

---

## 8. 위험 / 롤백 정책

### 8-1. 위험 항목

| # | 위험 | 영향 | 완화 |
|---|---|---|---|
| R1 | Polar이 `webhook-id` 헤더를 누락하는 경우 (스펙 외 동작) | eventId 부재 → 멱등성 실패 | step 2 fallback: status='failed' 박제 + 401 반환 (Polar 재전송 유도) + sensor warn 적재 |
| R2 | 기존 PROD payments 중 `status='completed'`인데 `webhook_events`에는 없는 row | 첫 webhook 재전송 시 duplicate_event가 아니라 `already_completed`로 분기 | 두 게이트 모두 안전 (둘 다 completePaymentAtomically 호출 0회). 신규 webhook부터만 webhook_events 박제 시작 — 데이터 backfill 불필요. |
| R3 | WebhookEvent 테이블 무한 증가 | 결제량 비례 적재, 1년 ~수만 row 예상 | retention 정책은 PAY-P1 (90일 archive). 본 Sprint는 데이터량 영향 무시 가능 (인덱스 `eventType+processedAt` 1개로 조회 부담 0). |
| R4 | Prisma P2002 catch 누락 시 race 발생 | 두 번째 호출이 INSERT 시 throw → controller가 500 응답 → Polar 무한 재시도 | createIfAbsent에서 반드시 try-catch + P2002 코드 명시. spec에서 P2002 mock으로 검증 강제. |
| R5 | sensor-payment-idempotency 미통과 시 commit 차단 | 개발 진행 막힘 | 본 Sprint 종료 시점에는 PASS 보장. WIP 단계는 sensor를 `--strict` 미적용으로 실행 (exit 0 보장). |

### 8-2. 롤백 정책

- **schema 차원**: WebhookEvent 모델 추가 + 신규 컬럼 0건 (기존 테이블 변경 0건) → 무중단 OK. 롤백 시 마이그레이션 down 미작성 (테이블 drop은 manual `DROP TABLE webhook_events`로 가능, 데이터 손실 허용).
- **코드 차원**: payment.usecase의 새 게이트는 `webhookEventRepo.findByEventId == null && create` 구조. 게이트 비활성화는 환경변수 `WEBHOOK_IDEMPOTENCY_DISABLED=1`로 즉시 우회 가능 (단, **prod에서는 절대 사용 금지** — 사고 시 사용자 직접 결정).
- **down.sql**:
  ```sql
  -- down.sql (참고용 — 실제 롤백 시 수동 실행)
  DROP TABLE IF EXISTS webhook_events;
  ```

### 8-3. 사전 백업 권장 (dev/prod 운영자)

```bash
pg_dump --table=payments --data-only > backup-payments-$(date +%Y%m%d).sql
# webhook_events는 신규 테이블 → 백업 불필요
```

---

## 9. 마이그레이션 정책 (server agent 준수)

1. **명명**: `{YYYYMMDDHHMMSS}_add_webhook_event_idempotency`
2. **up.sql**:
   ```sql
   CREATE TABLE "webhook_events" (
     "id" TEXT NOT NULL,
     "event_id" TEXT NOT NULL,
     "source" TEXT NOT NULL DEFAULT 'polar',
     "event_type" TEXT NOT NULL,
     "payload" JSONB NOT NULL,
     "status" TEXT NOT NULL,
     "error_message" TEXT,
     "processed_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
     CONSTRAINT "webhook_events_pkey" PRIMARY KEY ("id")
   );
   CREATE UNIQUE INDEX "webhook_events_event_id_key" ON "webhook_events"("event_id");
   CREATE INDEX "webhook_events_event_type_processed_at_idx" ON "webhook_events"("event_type", "processed_at");
   ```
3. **down.sql**: 미작성 (재실행 위험 0건 — 신규 테이블 추가만)
4. **schema.prisma 변경 후** `npx prisma migrate dev --name add_webhook_event_idempotency` (Generator가 실행)
5. **dev 배포 시**: `npx prisma migrate deploy` (운영자 또는 GitHub Actions)
6. **무중단 OK** — 기존 테이블 0건 변경

---

## 10. shared-contracts §11 신설 안 (claude-docs Generator 박제 정본)

claude-docs Generator는 아래 텍스트 블록을 `.claude/shared-contracts.md` `## 10. PostToolUseFailure hook 정책` 섹션 직후에 그대로 박제합니다 (`{HASH}{HASH}` 표기는 실제 markdown 헤딩 `#` 두/세 개로 치환):

```text
{HASH}{HASH} 11. WebhookEventIdempotency (server 도메인 — webhook 멱등성)

**위치**:
- 인터페이스: `grimoire-server/src/domain/port/outbound/webhook-event-repository.port.ts`
- DB 모델: `grimoire-server/prisma/schema.prisma` (WebhookEvent)
- 적용 대상: 모든 PG webhook 처리 (현재 Polar, 향후 다른 PG 어댑터도 동일 정책)

**적용**: payment.usecase.processWebhook + 향후 subscription.webhook / refund.webhook 등

{HASH}{HASH}{HASH} 시그니처

(본 sprint progress §3-4 그대로 복사 — WebhookEventRepositoryPort + WebhookEventRecord)

{HASH}{HASH}{HASH} 정책

- 모든 webhook은 `eventId` (PG가 발급한 unique 식별자) 박제 의무
- Polar: `webhook-id` 헤더
- 다른 PG 추가 시 어댑터가 NormalizedWebhookEvent.eventId 박제 책임
- DB unique 제약으로 race condition 차단 (P2002 catch → safe skip)

{HASH}{HASH}{HASH} 변경 이력
- 2026-05-03 PAY-P0-1: WebhookEventIdempotency 인터페이스 신설 (Polar webhook 재전송 멱등성 보장)
```

추가로 shared-contracts.md 파일 마지막 줄 `마지막 업데이트:` 라인을 `2026-05-03 (§11 WebhookEventIdempotency 신설)`로 교체합니다.

---

## 11. HANDOFF Chain

```
planner (Initializer — 본 sprint progress + PLANNER_REPORT 작성 완료)
  ↓
cost-accountant (사전 — ✅ 면제. AI 호출 0건 + 인프라 비용 영향 0건. WebhookEvent 테이블 row 적재 비용은 PostgreSQL 무시 가능.)
  ↓
visual-canon-keeper (사전 — ✅ 면제. 시각 정본 변경 0건 — 100% 백엔드 + sensor + 마이그레이션 + 정본 문서.)
  ↓
grimoire-server (Generator)
  - 본 progress.md §3 IN — server 13건 + §7 server 산출물 체크리스트 완수
  - DEV_REPORT.md Server 섹션 §5 raw stdout 전문 박제
  - 검증 게이트 G1~G6 모두 PASS
  ↓ (병렬 가능)
grimoire-claude-docs (Generator) — 메인 또는 planner 직접 박제
  - sensor + shared-contracts + eval task 신설
  - 검증 게이트 G7 + G8 PASS
  ↓
grimoire-qa (Evaluator)
  - AC 7건 raw 채점 (PASS/FAIL 박제)
  - QA_REPORT.md `### sprint-pay-p0-1-webhook-event-id-idempotency 통과율` 박제
  - dev curl 멱등성 수동 검증 (webhook 두 번 → 첫 호출만 처리)
  ↓
사용자 (배포 게이트 최종 판정)
  - qa PASS 시 develop → main per-repo 머지 (server + claude-docs 2 레포)
  - prod 배포 (npx prisma migrate deploy + Container Apps 재배포)
```

- **next agent**: grimoire-server + grimoire-claude-docs (병렬) → grimoire-qa
- **마감**: 본 세션 종료 전 dev 머지 (사용자 명시 — "dev까지 진행 + 머지")
- **단일 진실**: 본 progress.md (Generator/Evaluator 모두 본 파일 Read 후 작업, 모호하면 본 파일 갱신 후 합의)

---

## 12. 참조

- `research/PAYMENT_SYSTEM_PLAN.md` §3-1 PAY-P0-1
- `reports/PAYMENT_READINESS_AUDIT.md` (즉시 착수 가능 판정)
- `grimoire-server/src/application/payment/payment.usecase.ts:42~59` (현재 약식 멱등성)
- `grimoire-server/src/domain/port/outbound/payment-gateway.port.ts:29~40` (eventId 부재 실측)
- `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts:100~186` (verifyAndParseWebhook)
- `grimoire-server/CLAUDE.md` §9 결제/크레딧 원자성 원칙 + §3 문서 동기화
- `.claude/shared-contracts.md` §11 (본 Sprint에서 신설)
- 책 Ch 16 Anthropic 3-에이전트 (Initializer → Generator → Evaluator) — 묶음 II 3회차
- 책 Ch 16 충돌 2번 해결책 (shared state via DB unique constraint)
- 작업 C 사례: `reports/sprint-baked-css-url-absolute-progress.md` (패턴 참조)
- Polar Standard Webhooks 스펙: https://docs.polar.sh/webhooks (webhook-id 헤더)
