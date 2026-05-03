# Sprint Progress — pay-p1-1-refund-atomicity

> **Sprint ID**: sprint-pay-p1-1-refund-atomicity
> **세션**: #10_7 (3) PAY-P1-1 (PAYMENT_SYSTEM_PLAN §3-2 첫 번째 — Refund 정밀 처리, 크레딧 환수 트랜잭션)
> **Initializer**: grimoire-planner (책 Ch 16 Anthropic 3-에이전트 패턴 — 묶음 II 6회차)
> **작성일**: 2026-05-03
> **단일 진실**: 본 파일이 Generator (server / claude-docs) + Evaluator (qa) 모두의 작업 정본. 모호하면 본 파일 갱신 후 합의.
> **선행 Sprint (PAY-P0 100% 완료)**:
> - PAY-P0-1 (sprint-pay-p0-1-webhook-event-id-idempotency-progress.md) — server `8c13103` + claude-docs `06de6c6`
> - PAY-P0-2 (sprint-pay-p0-2-payment-reconciliation-cron-progress.md) — server `8e9e02e` + web `849f771` + claude-docs `790e692`
> - PAY-P0-3 (sprint-pay-p0-3-admin-credit-grant-ui-progress.md) — web `af3f04c` + claude-docs `841e704`

---

## 0. Goal — 한 줄

Polar 환불 webhook 수신 시 **크레딧 자동 환수 트랜잭션**을 도입하여 환불 적자 위험을 차단한다. 사용자 잔액 < refund credits 케이스는 0 fix + RefundLog.deficitCredits 박제 + AdminAuditLog(operator='system_refund') 기록. PAY-P0-1 webhook_events 테이블의 `eventId @unique` 게이트로 환불 webhook 멱등성도 자동 보장.

---

## 1. 배경 (메인 사전 파악 — 실측 박제)

### 1-1. 현재 갭 (PAYMENT_SYSTEM_PLAN §1-5 #4)

> **Refund 정밀 처리 부재** — webhook에서 status='refunded' 마킹만, **크레딧 환수 트랜잭션 없음**. 환불 시 사용자가 크레딧 그대로 보유 → 적자 위험.

### 1-2. 백엔드 인벤토리 (실측)

`grimoire-server/src/application/payment/payment.usecase.ts:55-58` (재현):

```typescript
} else {
  await this.paymentRepo.updateStatus(payment.id, event.status === 'cancel' ? 'refunded' : 'failed')
  await this.webhookEventRepo.createIfAbsent({
    eventId: event.eventId,
    source: 'polar',
    eventType: event.type,
    payload: event as unknown as object,
    status: 'processed',
  })
  return { processed: true, credits: 0 }
}
```

**갭 정밀 분석**:
- `event.status === 'cancel'` 분기에서 `paymentRepo.updateStatus(payment.id, 'refunded')`만 호출 — Payment row의 status 컬럼만 'refunded'로 마킹
- `Author.credits` 변동 0 → 사용자가 크레딧 그대로 보유 + 환불금 수령 (적자)
- `CreditLog` 기록 0건 → 추적 불가
- `AdminAuditLog` 기록 0건 → 시스템 환불 처리 추적 불가

### 1-3. 적용 대상 코드 인벤토리

| 영역 | 위치 | 상태 |
|---|---|---|
| **분기 호출 위치** | `payment.usecase.ts:55-58` ('cancel' 분기 — 환불 처리) | ⚠️ usecase 호출 신설 대상 |
| **현재 트랜잭션 패턴** | `prisma-payment.repository.ts:25-39` (`completePaymentAtomically` $transaction) | ✅ 정합 패턴 — refundPaymentAtomically도 동일 $transaction 패턴 차용 |
| **Author.credits 컬럼** | `prisma/schema.prisma:19` (`credits Int @default(0)`) | ✅ 기존 컬럼 활용 |
| **CreditLog 테이블** | `prisma/schema.prisma:97-105` (`authorId/amount/reason/createdAt`) | ✅ 기존 테이블 — 환수는 amount 음수로 박제 (관례 정합 검증 필요 — Generator §3-3) |
| **AdminAuditLog 테이블** | `prisma/schema.prisma:387-398` (`adminId/action/targetId/detail JSON`) | ✅ 기존 테이블 — operator='system_refund'로 박제 (PAY-P0-2 'system_reconciliation' 패턴 정합) |
| **WebhookEvent 멱등성** | `prisma/schema.prisma:212-224` (PAY-P0-1 신설 `eventId @unique`) | ✅ 멱등성 자동 — refund webhook 두 번 수신 시 P2002 차단 |
| **audit-log.service.log** | `application/admin/audit-log.service.ts:14-15` (`log(adminId, action, targetId?, detail?)`) | ✅ 기존 시그니처 활용 |

### 1-4. RefundLog 신규 모델 — 박제 사유

**왜 CreditLog로 충분하지 않은가**:
- CreditLog는 amount/reason만 박제 (refund 금액·source·deficit 별도 박제 불가)
- **deficitCredits** (잔액 부족 시 외상 박제) 컬럼이 필수 — CreditLog로는 표현 불가
- **source** ('webhook' | 'manual') 분기 박제 — 향후 운영자 수동 환불(P2) 도입 시 식별 필요
- 환불 추적 전용 테이블이 운영 reporting에 유리 (PAYMENT_SYSTEM_PLAN §4 권장 모델 정합)

### 1-5. 잔액 부족 시나리오 (deficit 분기 정밀)

**시나리오 가정** (실제 발생 가능):
1. 사용자가 5,000원 결제 → 50 크레딧 부여
2. 사용자가 30 크레딧 소비 (AI 분석 등)
3. 사용자가 환불 요청 → Polar 'cancel' webhook 도착
4. 환수해야 할 크레딧: 50 → 그러나 잔액은 20 (소비 후)
5. **분기**:
   - 정상 환수 불가 — 음수 잔액 회피 필요
   - **결정**: Author.credits = 0 fix + RefundLog.deficitCredits = 30 박제 + AdminAuditLog(action='refund_deficit') 박제
   - 운영자가 RefundLog 조회 후 정책 결정 (외상 회수 / 손실 처리 / 사용자 협상)

**왜 음수 허용 불가**:
- Author.credits 컬럼은 `@default(0)` Int — 음수 가능 (DB 차원 제약 0)
- 그러나 음수 잔액 보유 시 다음 결제·차감 로직에 일관성 깨짐 (UI 표시 / decrement 로직 / 가입 직후 신호 등)
- **정책**: 음수 절대 차단, 0 fix + 부족분(`deficitCredits`)은 RefundLog에만 박제

### 1-6. 멱등성 자동 보장 (PAY-P0-1 활용)

`payment.usecase.processWebhook`은 가장 먼저 `webhookEventRepo.findByEventId(event.eventId)` 게이트 통과 (line 61-65). 같은 환불 webhook이 재전송되어도:
- 첫 호출 → refund 처리 + WebhookEvent 'processed' 박제
- 두 번째 호출 → findByEventId 적중 → 즉시 `{ processed: false, reason: 'duplicate_event' }` 반환

→ **AC-7 (멱등성)은 PAY-P0-1 인프라로 자동 충족**. 별도 처리 불필요. spec에서 회귀 검증만.

### 1-7. 실측 grep (Generator 출발점)

```bash
$ grep -nE "event.status === 'cancel'" grimoire-server/src/application/payment/payment.usecase.ts
126:      await this.paymentRepo.updateStatus(payment.id, event.status === 'cancel' ? 'refunded' : 'failed')

$ grep -nE "refundPayment|RefundLog" grimoire-server/src/
(0건 — 신설 대상)

$ grep -nE "completePaymentAtomically" grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts
25:  async completePaymentAtomically(paymentId: string, authorId: string, credits: number, productId: string): Promise<void> {

$ grep -nE "AuditLogRepositoryPort|auditLog.log|auditLog\\.service" grimoire-server/src/application/admin/
(audit-log.service.ts log 시그니처 박제 — Generator는 본 service를 DI로 활용 또는 repo 직접 활용 결정)
```

---

## 2. Scope

### 2-1. IN

| 항목 | 영역 | 파일 (예상 경로) |
|---|---|---|
| **RefundLog Prisma 모델 신설** | server | `grimoire-server/prisma/schema.prisma` (RefundLog 모델 — id/paymentId/amount/credits/deficitCredits/reason/processedAt/source) |
| **마이그레이션 신설** | server | `grimoire-server/prisma/migrations/{ts}_add_refund_log/` (CREATE TABLE refund_logs + INDEX paymentId — INSERT seed 0건) |
| **RefundPaymentUseCase 신설** | server | `grimoire-server/src/application/payment/refund-payment.usecase.ts` (정상 환수 + deficit 분기 + AuditLog 호출) |
| **RefundPaymentUseCase spec 신설** | server | `grimoire-server/src/application/payment/refund-payment.usecase.spec.ts` (≥5 it 블록 — 정상 환수 / deficit / 잔액=환수 / payment 미존재 / 이미 refunded) |
| **PaymentRepositoryPort 확장** | server | `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (`refundPaymentAtomically(paymentId, authorId, credits, refundedAmount, reason): Promise<{ deficitCredits: number }>`) |
| **PrismaPaymentRepository 구현 신설** | server | `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (`refundPaymentAtomically` $transaction — Payment.status='refunded' + Author.credits decrement(0 fix) + CreditLog 음수 amount 박제 + RefundLog 박제) |
| **RefundLog Repository Port + Adapter** | server | `grimoire-server/src/domain/port/outbound/refund-log-repository.port.ts` 신설 + `prisma-refund-log.repository.ts` 신설 (또는 PaymentRepository 내부에서 prisma.refundLog 직접 활용 — Generator §3-1 결정) |
| **payment.usecase.ts 'cancel' 분기 신설** | server | `payment.usecase.ts:125-135` ('cancel' 분기에서 refund usecase 호출 — `event.status === 'cancel'` 정확히 1회) |
| **payment.usecase.spec.ts 회귀 spec 추가** | server | `payment.usecase.spec.ts` ('cancel' webhook → refundPaymentUseCase.execute 1회 호출 검증) |
| **app.module.ts DI 추가** | server | `grimoire-server/src/app.module.ts` (RefundPaymentUseCase + RefundLogRepository 또는 PrismaPaymentRepository.refundPaymentAtomically 활용 시 DI 신설 0건) |
| **server 정본 문서 동기화** | server | `docs/data-model.md` + `SCHEMA.md` (RefundLog 박제) + `docs/api-contract.md` (변경 0건 — webhook은 기존 endpoint) + `MIGRATION.md` (정책 변경 시) |
| **server TECH_STATUS / CHANGELOG** | server | `TECH_STATUS.md` (PAY-P1-1 박제) + `CHANGELOG.md` `[Unreleased]` Added 박제 |
| **sensor 신설** | claude-docs | `.claude/scripts/sensor-refund-atomicity.sh` (검증 항목 ≥7건 — RefundLog 모델 / refundPaymentAtomically grep / 'cancel' 분기 호출 / spec it 블록 / deficit 분기 / AuditLog operator='system_refund') |
| **eval regression-55** | claude-docs | `eval/tasks/regression-55-refund-atomicity.json` (eval_criteria ≥6건) |
| **shared-contracts §13 신설** | claude-docs | `.claude/shared-contracts.md` §13 — RefundPaymentAtomically 인터페이스 박제 + 변경 이력 |
| **research/HARNESS_ENGINEERING.md §14.4 갱신** | claude-docs | Sensors 28→29 + sensor-refund-atomicity 행 + eval task 54→55 |

### 2-2. OUT

- **부분 환불 (partial refund)** — Payment.refundedAmount/refundedCredits 컬럼 확장은 **PAY-P2-1** (PAYMENT_SYSTEM_PLAN §3-3). 본 Sprint는 전액 환불만.
- **운영자 수동 환불 web UI** — `POST /admin/payments/:paymentId/refund` 신규 endpoint + admin tab 신설은 PAY-P2 범위. 본 Sprint는 webhook 자동 처리만 (`source='webhook'` 고정).
- **이메일 환불 알림** — `PAY-P1-2` (결제 알림 이메일) 영역. 본 Sprint는 알림 호출 0건.
- **DLQ (Dead Letter Queue)** — 환불 처리 실패 시 영구 박제는 PAY-P2-2. 본 Sprint는 throw 시 webhook event 'failed' 박제 + Polar 자체 retry 의존 (PAY-P0-1 기존 패턴 정합).
- **AdminAuditLog before/after 박제 강화** — PAY-P2-3. 본 Sprint는 detail JSON에 paymentId/credits/deficitCredits/refundedAmount/reason만 박제.
- **web 변경 0건** — 본 Sprint는 100% server + claude-docs. CreditLog 음수 박제는 기존 web admin tab(PaymentsTab/CreditsTab)에서 별도 UI 변경 없이 자동 표시. 향후 환불 전용 표시 UI는 P2.

---

## 3. 결정 사항 (Initializer 최종)

### 3-1. RefundLog Repository 분리 vs PaymentRepository 통합 — 결정 보류 (Generator)

**[옵션 A — 권고]**: PaymentRepository 통합
- `prisma-payment.repository.ts` 내부에서 `prisma.refundLog.create({ ... })` 호출
- 장점: DI 신설 0건, $transaction 자연스러움 (단일 tx 클로저)
- 단점: Hexagonal 엄격성 약화 (PaymentRepo가 RefundLog 박제 책임 겸직)

**[옵션 B — 대안]**: 별도 Port + Adapter
- `domain/port/outbound/refund-log-repository.port.ts` 신설
- `prisma-refund-log.repository.ts` 신설
- 장점: Hexagonal 정합 + 테스트 mock 분리
- 단점: $transaction 인자 전달 복잡도 (prisma client 공유)

**Generator 결정**:
- 옵션 A 채택 권고 — PAY-P0-2 `prisma-reconciliation-checkpoint.repository.ts`와 같은 분리 패턴은 단일 row + 독립 책임에 적합. RefundLog는 Payment에 종속 (1:N) + $transaction 내부에서 박제 → 옵션 A가 자연스러움.
- 옵션 B 채택 시 본 progress.md §3-1 갱신 후 사용자 결정.

### 3-2. 'cancel' 분기 신설 정밀

**현재** (`payment.usecase.ts:125-135`):
```typescript
} else {
  await this.paymentRepo.updateStatus(payment.id, event.status === 'cancel' ? 'refunded' : 'failed')
  await this.webhookEventRepo.createIfAbsent({ ... status: 'processed' })
  return { processed: true, credits: 0 }
}
```

**변경 후** (decision):
```typescript
} else if (event.status === 'cancel') {
  // 환불 처리 — 크레딧 환수 트랜잭션 + RefundLog + AuditLog
  const result = await this.refundPaymentUseCase.execute({
    paymentId: payment.id,
    authorId: payment.authorId,
    credits: payment.credits,
    refundedAmount: event.amount,
    reason: `polar_webhook_${event.type}`,
    source: 'webhook',
  })
  await this.webhookEventRepo.createIfAbsent({ ... status: 'processed' })
  return { processed: true, credits: 0, deficitCredits: result.deficitCredits }
} else {
  // event.status === 'fail' — 결제 실패 (크레딧 환수 대상 아님)
  await this.paymentRepo.updateStatus(payment.id, 'failed')
  await this.webhookEventRepo.createIfAbsent({ ... status: 'processed' })
  return { processed: true, credits: 0 }
}
```

**[MUST]**:
- `event.status === 'cancel'` 분기 안에서 `refundPaymentUseCase.execute` 정확히 1회 호출 (spec toHaveBeenCalledTimes(1) 검증)
- `event.status === 'fail'` 분기에서는 refund usecase 호출 0회 (단순 status 갱신만 — 결제 실패는 환수 대상 0)
- WebhookEvent 박제는 양 분기 모두 status='processed'

### 3-3. CreditLog 음수 박제 정책

**[MUST]** 환수 시 CreditLog.amount는 **음수**로 박제:
- 정상 환수: `amount = -credits` (예: -50)
- deficit 케이스: `amount = -actualDeducted` (실제 차감된 양만 — 잔액 부족분 미포함)
- reason: `refund_${paymentId}_polar_webhook`

**근거**: `prisma-payment.repository.ts:35-37` `completePaymentAtomically`이 `amount: credits` (양수)로 박제 → 환수는 대칭적으로 음수. CreditLog 합산 시 계정 잔액 = SUM(amount) 정합.

**Generator 검증 grep**:
```bash
grep -rnE "creditLog.create.*amount" grimoire-server/src/
```
음수/양수 관례 검증 후 본 progress.md §3-3 갱신 가능.

### 3-4. AdminAuditLog 시그니처 정밀

**[MUST]** RefundPaymentUseCase 내부에서 auditLog.log 호출:

```typescript
await this.auditLogService.log(
  'system_refund',                          // operator (PAY-P0-2 'system_reconciliation' 패턴 정합)
  deficitCredits > 0 ? 'refund_deficit' : 'refund_normal',  // action
  paymentId,                                // targetId
  {                                         // detail JSON
    authorId,
    refundedAmount,
    creditsRequested: credits,
    creditsActuallyDeducted: actualDeducted,
    deficitCredits,
    reason,
    source,
  }
)
```

**기각 대안**:
- `operator='polar_webhook'` — 일관성 깨짐 (PAY-P0-2 'system_reconciliation' 정합성 우선)
- `action='refund'` 단일 — deficit 분기 식별 불가 → reporting 곤란

### 3-5. RefundPaymentUseCase 시그니처 정본

```typescript
@Injectable()
export class RefundPaymentUseCase {
  constructor(
    @Inject('PaymentRepositoryPort') private readonly paymentRepo: PaymentRepositoryPort,
    private readonly auditLogService: AuditLogService,
  ) {}

  /**
   * 환불 처리 — 크레딧 환수 + RefundLog + AuditLog 박제 (단일 트랜잭션 + AuditLog 후행)
   *
   * 분기:
   * - 정상 환수 (Author.credits >= credits): credits 만큼 decrement, deficitCredits=0
   * - deficit 환수 (Author.credits < credits): Author.credits=0 fix, deficitCredits=credits-잔액
   *
   * 멱등성: payment.status === 'refunded' 시 즉시 skip (재처리 차단)
   */
  async execute(input: {
    paymentId: string
    authorId: string
    credits: number              // 환수 대상 크레딧 (양수)
    refundedAmount: number       // 환불 금액 (KRW)
    reason: string
    source: 'webhook' | 'manual'
  }): Promise<{
    actualDeducted: number       // 실제 차감된 크레딧 (deficit 시 잔액)
    deficitCredits: number       // 잔액 부족분 (정상 환수 시 0)
  }>
}
```

**[MUST]**:
- 함수 시그니처는 **객체 인자 1개 + 반환 객체** (위치 인자 금지 — 인자 순서 실수 차단)
- `credits`는 항상 양수 입력 (반환 시 음수 변환은 내부 책임)
- `deficitCredits` 반환 → 호출자(payment.usecase)가 응답에 포함하여 추적 가능

### 3-6. refundPaymentAtomically Repository 시그니처

```typescript
// PaymentRepositoryPort 확장
refundPaymentAtomically(input: {
  paymentId: string
  authorId: string
  credits: number              // 환수 대상 (양수)
  refundedAmount: number       // 환불 금액
  reason: string
  source: 'webhook' | 'manual'
}): Promise<{
  actualDeducted: number
  deficitCredits: number
}>
```

**$transaction 내부 처리 순서** (정합 의무):
1. `tx.author.findUnique({ where: { id: authorId }, select: { credits: true } })` — 현재 잔액 SELECT FOR UPDATE 권고 (race 차단)
2. `actualDeducted = Math.min(credits, currentBalance)` 계산
3. `deficitCredits = credits - actualDeducted`
4. `tx.payment.update({ where: { id: paymentId }, data: { status: 'refunded' } })` (이미 refunded면 P2002 또는 affected row 0 → throw — Generator §3-7 결정)
5. `tx.author.update({ where: { id: authorId }, data: { credits: { decrement: actualDeducted } } })` (잔액 0 보장)
6. `tx.creditLog.create({ data: { authorId, amount: -actualDeducted, reason: \`refund_${paymentId}_${source}\` } })`
7. `tx.refundLog.create({ data: { paymentId, amount: refundedAmount, credits: actualDeducted, deficitCredits, reason, processedAt, source } })`
8. return `{ actualDeducted, deficitCredits }`

### 3-7. 멱등성 + race 차단 정책

**[MUST]** 멱등성은 **3중 게이트**로 자동 보장:
1. **L1 — webhook event_id** (PAY-P0-1): payment.usecase.processWebhook line 61-65 → 같은 webhook 재전송 시 즉시 skip
2. **L2 — payment.status 게이트**: 이미 'refunded'면 refundPaymentAtomically 첫 줄에서 skip (또는 SELECT 후 throw)
3. **L3 — RefundLog @@unique([paymentId])** (선택 — Generator 권고): 같은 paymentId의 RefundLog 중복 박제 차단

**Generator 결정 영역**: L3 unique 도입 여부.
- 도입 권고 시: schema.prisma `@@unique([paymentId])` (전액 환불만 가정 시 1:1 — 부분 환불 P2-1 도입 시 제거 필요)
- 미도입 시: L1+L2로 충분

본 progress.md §3-7는 **L3 미도입** (P2-1 부분 환불 호환성 우선) 권고. 단 spec에서는 L1+L2 회귀 검증.

### 3-8. payment.usecase.processWebhook 응답 시그니처 변경

**현재**: `{ processed: true, credits: 0 }`
**변경 후 (cancel 분기)**: `{ processed: true, credits: 0, deficitCredits: number }` (deficit > 0이면 운영자 알림 신호)

**[MUST]** controller 응답 시그니처 정합 검증 — `payment.controller.ts` 변경 0건이면 응답이 자동으로 클라이언트에 전달됨. 응답 스키마 갱신은 `docs/api-contract.md` 박제 의무.

### 3-9. 잔액=환수 정확히 같은 케이스 (edge case)

**시나리오**: Author.credits === credits (환수 대상)
- actualDeducted = credits
- deficitCredits = 0
- Author.credits = 0 (정상 환수)
- 정상 분기로 처리 (deficit 분기 0)

**[MUST]** spec에서 별도 it 블록으로 검증 (boundary).

---

## 4. Acceptance Criteria (AC) — 7건, Ambiguity ≤ 0.1

각 AC는 **실측 검증 가능한 raw stdout / grep 결과 / spec 결과 / sensor 결과**로 증명. Generator는 본 AC를 충족하지 못하면 작업 미완료 박제 (DEV_REPORT.md에 raw stdout 박제).

### AC-1: RefundLog Prisma 모델 + 마이그레이션 + INSERT seed 0건

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
grep -nE "model RefundLog" prisma/schema.prisma
grep -nE "deficitCredits|deficit_credits" prisma/schema.prisma
ls prisma/migrations/ | grep -iE "refund_log"
cat prisma/migrations/*_add_refund_log*/migration.sql | grep -iE "CREATE TABLE.*refund_logs"
cat prisma/migrations/*_add_refund_log*/migration.sql | grep -iE "INSERT INTO" | wc -l
```

**기대 raw 출력**:
- `model RefundLog` 1건 존재
- `deficitCredits Int @default(0)` 박제
- 마이그레이션 디렉토리 1건 존재 (예: `20260503_add_refund_log/`)
- `CREATE TABLE "refund_logs"` 박제 + INDEX `paymentId`
- `INSERT INTO` 결과 **0건** (신규 테이블 — seed 0건 강제)

### AC-2: RefundPaymentAtomically $transaction + spec (정상 + deficit 분기 모두 toHaveBeenCalledWith 검증)

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
grep -nE "refundPaymentAtomically" src/domain/port/outbound/payment-repository.port.ts
grep -nE "refundPaymentAtomically" src/adapter/outbound/persistence/prisma-payment.repository.ts
grep -nE "\\\$transaction" src/adapter/outbound/persistence/prisma-payment.repository.ts | wc -l
test -f src/application/payment/refund-payment.usecase.ts
test -f src/application/payment/refund-payment.usecase.spec.ts
grep -nE "describe\\('RefundPaymentUseCase'|it\\(|test\\(" src/application/payment/refund-payment.usecase.spec.ts
grep -nE "toHaveBeenCalledWith|toHaveBeenCalledTimes" src/application/payment/refund-payment.usecase.spec.ts | wc -l
npx jest src/application/payment/refund-payment.usecase.spec.ts 2>&1 | tail -20
```

**기대 raw 출력**:
- `refundPaymentAtomically` 시그니처 port + 구현 둘 다 박제
- `$transaction` 호출 ≥2건 (completePaymentAtomically + refundPaymentAtomically)
- spec 파일 존재 + describe 블록 1건
- `it` 또는 `test` 블록 ≥5건:
  - it-1: 정상 환수 (Author.credits >= credits) — Author.credits decrement(credits) 호출 1회 + creditLog.create amount=-credits 호출 1회 + refundLog.create deficitCredits=0 검증 (toHaveBeenCalledWith)
  - it-2: deficit 환수 (Author.credits < credits) — Author.credits 0 fix + creditLog.create amount=-actualDeducted + refundLog.create deficitCredits>0 검증 + AuditLog action='refund_deficit' 검증
  - it-3: 잔액 정확히 같음 (boundary) — 정상 분기 처리 검증
  - it-4: payment 미존재 — throw 또는 NotFoundException 검증
  - it-5: 이미 refunded payment — skip 또는 BadRequest 검증
- `toHaveBeenCalledWith` 또는 `toHaveBeenCalledTimes` 호출 ≥5건 (더미 assertion 0건 — 실제 mock 호출 검증)
- jest stdout: `Tests: X passed`, 실패 0건

### AC-3: payment.usecase.processWebhook 'cancel' 분기에서 refund usecase 호출 (event.status='cancel' → 정확히 1회)

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
grep -nE "event.status === 'cancel'" src/application/payment/payment.usecase.ts
grep -nE "refundPaymentUseCase" src/application/payment/payment.usecase.ts
grep -nE "refundPaymentUseCase|RefundPaymentUseCase" src/application/payment/payment.usecase.spec.ts
grep -nE "toHaveBeenCalledTimes\\(1\\)" src/application/payment/payment.usecase.spec.ts
npx jest src/application/payment/payment.usecase.spec.ts 2>&1 | tail -20
```

**기대 raw 출력**:
- `payment.usecase.ts`에 `event.status === 'cancel'` 분기 박제 (else if 또는 분기 식별)
- `refundPaymentUseCase.execute(` 호출 1건 (cancel 분기 내부)
- `payment.usecase.spec.ts`에 RefundPaymentUseCase mock 박제
- 'cancel' webhook 시나리오 spec → `mockRefundPaymentUseCase.execute` `toHaveBeenCalledTimes(1)` 검증
- 'fail' webhook 시나리오 spec → `mockRefundPaymentUseCase.execute` `toHaveBeenCalledTimes(0)` 검증 (회귀)
- jest stdout: 'cancel' / 'fail' / 'success' 분기 spec 모두 PASS

### AC-4: 사용자 잔액 < refund credits 시 0 fix + deficit 박제 + AuditLog operator='system_refund'

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
grep -nE "system_refund" src/application/payment/refund-payment.usecase.ts
grep -nE "refund_deficit|refund_normal" src/application/payment/refund-payment.usecase.ts
grep -nE "Math.min|currentBalance|balance.*credits|deficitCredits" src/application/payment/refund-payment.usecase.ts
grep -nE "refund_deficit|deficitCredits" src/application/payment/refund-payment.usecase.spec.ts
grep -nE "Author.credits.*0|credits.*decrement.*actualDeducted" src/adapter/outbound/persistence/prisma-payment.repository.ts
```

**기대 raw 출력**:
- `'system_refund'` 문자열 박제 1건 (operator)
- `'refund_deficit'` + `'refund_normal'` 분기 박제 (action)
- `Math.min` 또는 boundary 계산 박제 (잔액 < credits 처리)
- spec에서 `'refund_deficit'` action 박제 + deficitCredits > 0 검증
- 0 fix 박제 (decrement actualDeducted 또는 min(credits, balance))

### AC-5: regression-55 + sensor-refund-atomicity.sh 신설 + eval 54→55 PASS

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire
cat eval/tasks/regression-55-refund-atomicity.json | python3 -c "import json,sys;d=json.load(sys.stdin);print(len(d['eval_criteria']))"
ls eval/tasks/regression-*.json | wc -l
ls -la .claude/scripts/sensor-refund-atomicity.sh
bash .claude/scripts/sensor-refund-atomicity.sh
echo "exit: $?"
bash eval/scripts/eval-runner.sh 2>&1 | tail -10
```

**기대 raw 출력**:
- regression-55 JSON 존재 + eval_criteria ≥6건
- `ls regression-*.json | wc -l` 결과 55 (현재 54)
- sensor 파일 존재 + chmod +x
- 직접 실행 시 PASS (exit 0) — 검증 항목 ≥7건:
  1. RefundLog 모델 schema.prisma 박제
  2. refundPaymentAtomically 시그니처 박제 (port + impl)
  3. RefundPaymentUseCase 파일 존재 + spec 존재
  4. payment.usecase.ts 'cancel' 분기에서 refundPaymentUseCase.execute 호출
  5. spec ≥5 it 블록 + toHaveBeenCalledWith ≥5건 (더미 assertion 차단)
  6. operator='system_refund' + action 분기 박제
  7. deficitCredits 박제 패턴 검증
- eval-runner stdout 마지막 행: `regression: 55/55 PASS (100%)` 또는 동등

### AC-6: shared-contracts §13 RefundPaymentAtomically 박제

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire
grep -nE "^## 13\\. RefundPaymentAtomically" .claude/shared-contracts.md
grep -nE "deficitCredits|actualDeducted" .claude/shared-contracts.md
grep -nE "2026-05-03 #10_7 PAY-P1-1" .claude/shared-contracts.md
bash .claude/scripts/sensor-shared-contracts.sh
echo "exit: $?"
```

**기대 raw 출력**:
- `## 13. RefundPaymentAtomically` 섹션 헤더 박제
- 시그니처 박제 (`deficitCredits`, `actualDeducted` 둘 다 등장)
- 변경 이력에 `2026-05-03 #10_7 PAY-P1-1: 신설` 박제
- sensor-shared-contracts.sh PASS (drift 0)

### AC-7: 멱등성 — 같은 webhook event 두 번 수신 시 refund 1회만 (PAY-P0-1 webhook_events 테이블 활용)

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
grep -nE "duplicate_event|findByEventId" src/application/payment/payment.usecase.ts
grep -nE "duplicate_event|findByEventId" src/application/payment/payment.usecase.spec.ts
grep -nE "refundPaymentUseCase.*toHaveBeenCalledTimes\\(0\\)|refundPaymentUseCase.*not\\.toHaveBeenCalled" src/application/payment/payment.usecase.spec.ts
npx jest -t "duplicate" src/application/payment/payment.usecase.spec.ts 2>&1 | tail -15
```

**기대 raw 출력**:
- `findByEventId` 호출 박제 (PAY-P0-1 인프라 — 변경 0건)
- spec에 'duplicate webhook' 또는 동등 시나리오 it 블록
- 회귀 검증: 같은 eventId 두 번 호출 시 `refundPaymentUseCase.execute` `toHaveBeenCalledTimes(0)` (두 번째 호출은 멱등 게이트 적중) — 또는 `toHaveBeenCalledTimes(1)` (전체 spec에서 첫 호출만)
- jest 'duplicate' 시나리오 it 블록 PASS

---

## 5. Test Plan

### 5-1. 단위 테스트 (jest)

| spec 파일 | 신규 it 블록 |
|---|---|
| `refund-payment.usecase.spec.ts` (신설) | (a) 정상 환수 (Author.credits >= credits) — Author.credits decrement(credits) + creditLog amount=-credits + refundLog deficitCredits=0 + auditLog action='refund_normal' (b) deficit 환수 (Author.credits < credits) — Author.credits 0 fix + creditLog amount=-actualDeducted + refundLog deficitCredits>0 + auditLog action='refund_deficit' (c) 잔액 정확히 같음 — 정상 분기 (d) payment 미존재 — throw NotFoundException 또는 동등 (e) 이미 refunded payment — skip 또는 BadRequestException (f) source='webhook' / source='manual' 양쪽 reason 패턴 검증 |
| `payment.usecase.spec.ts` (회귀 spec 추가) | (g) 'cancel' webhook → refundPaymentUseCase.execute 1회 호출 + status='processed' webhook event 박제 (h) 'fail' webhook → refundPaymentUseCase.execute 0회 호출 + paymentRepo.updateStatus('failed') 1회 (i) 같은 eventId 중복 webhook → refundPaymentUseCase.execute 0회 호출 (PAY-P0-1 게이트 회귀) (j) cancel webhook 응답에 deficitCredits 포함 검증 |
| `prisma-payment.repository.spec.ts` (선택 — refundPaymentAtomically 통합 테스트) | (k) DB 레벨 $transaction 정상 처리 — Payment.status='refunded' + Author.credits decrement + CreditLog/RefundLog row 박제 (선택, jest mockPrisma 또는 testcontainer) |

mock 패턴 (Generator 참고):
```typescript
const mockPaymentRepo = {
  refundPaymentAtomically: jest.fn().mockResolvedValue({ actualDeducted: 50, deficitCredits: 0 }),
  // ...
}
const mockAuditLogService = { log: jest.fn() }

it('정상 환수 — credits=50 보유 시 50 decrement + deficitCredits=0', async () => {
  mockPaymentRepo.refundPaymentAtomically.mockResolvedValueOnce({ actualDeducted: 50, deficitCredits: 0 })
  const result = await usecase.execute({ paymentId: 'p1', authorId: 'a1', credits: 50, refundedAmount: 5000, reason: 'r', source: 'webhook' })
  expect(mockPaymentRepo.refundPaymentAtomically).toHaveBeenCalledWith({
    paymentId: 'p1', authorId: 'a1', credits: 50, refundedAmount: 5000, reason: 'r', source: 'webhook',
  })
  expect(mockAuditLogService.log).toHaveBeenCalledWith('system_refund', 'refund_normal', 'p1', expect.objectContaining({ deficitCredits: 0 }))
  expect(result.deficitCredits).toBe(0)
})
```

**[MUST 사용자 명시]**: `toHaveBeenCalledWith` / `toHaveBeenCalledTimes` / `mock.calls` 등 **실제 mock 호출 검증**을 모든 it 블록에서 사용. `expect(true).toBe(true)` / `expect(1+1).toBe(2)` 등 더미 assertion 0건. AC-2 grep 검증으로 자동 차단.

### 5-2. 통합 테스트 — 수동 (localhost)

`reports/sprint-pay-p1-1-refund-atomicity-progress.md` Generator 단계에서:
1. localhost server (3000) 부팅 + Polar webhook 시뮬 (curl 또는 stub)
2. 시드 사용자 결제 시뮬 (Payment.create + Author.credits = 50)
3. Author.credits를 30으로 수동 갱신 (소비 시뮬)
4. Polar 'order.refunded' webhook curl 전송 (eventId / tradeNo / amount=5000 / status='cancel')
5. 응답 검증: `{ processed: true, credits: 0, deficitCredits: 20 }` (50 - 30)
6. psql 검증:
   - `SELECT * FROM payments WHERE id='p1'` → status='refunded'
   - `SELECT credits FROM authors WHERE id='a1'` → 0 (0 fix)
   - `SELECT * FROM credit_logs WHERE author_id='a1' ORDER BY created_at DESC LIMIT 1` → amount=-30, reason='refund_p1_webhook'
   - `SELECT * FROM refund_logs WHERE payment_id='p1'` → credits=30, deficit_credits=20, source='webhook'
   - `SELECT * FROM admin_audit_logs WHERE action='refund_deficit' ORDER BY created_at DESC LIMIT 1` → adminId='system_refund', detail JSON에 deficitCredits=20
7. 같은 eventId webhook 재전송 시 `{ processed: false, reason: 'duplicate_event' }` + DB 변동 0 검증

**raw 박제 위치**: DEV_REPORT.md Server 섹션 §3 구현 결과 + §5 sensor 결과 (psql SELECT 결과 전문 + curl raw response).

### 5-3. sensor 회귀

- `sensor-credit-atomicity` PASS 유지 (강화 — refundPaymentAtomically도 $transaction 패턴 검증 포함)
- `sensor-payment-idempotency` (PAY-P0-1) PASS 유지
- `sensor-payment-reconciliation` (PAY-P0-2) PASS 유지
- `sensor-admin-credit-ui` (PAY-P0-3) PASS 유지
- `sensor-refund-atomicity` (신설) PASS
- `sensor-shared-contracts` PASS (§13 신설로 mtime 갱신)
- `sensor-server` PASS (`npm test` + `npx tsc --noEmit` 0 errors)
- `sensor-docs-sync` PASS
- `sensor-adversarial-pre-commit` 19 principles PASS (P16 결제 원자성 강화 — refundPaymentAtomically도 $transaction 검증 추가 가능)

### 5-4. eval 회귀

- regression-50/51/52/53/54 PASS 유지
- regression-55 (본 Sprint 신설) PASS
- regression 54→55 / EDD 21~33 모두 PASS (drift 0)

---

## 6. 검증 게이트 (Generator → Evaluator 핸드오프 전 필수 통과)

### 6-1. server 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G1 | TypeScript | `cd grimoire-server && npx tsc --noEmit` | 0 errors |
| G2 | Lint | `npm run lint` | 0 errors |
| G3 | jest (전체) | `npm test 2>&1 \| tail -30` | 모든 spec PASS, 회귀 0건, 신규 spec ≥5 it 블록 모두 PASS |
| G4 | Build | `npm run build` | 0 errors |
| G5 | Prisma | `npx prisma migrate diff --from-schema-datamodel prisma/schema.prisma --to-schema-datasource prisma/schema.prisma` | 차이 0건 (마이그레이션과 schema 정합) |
| G6 | Prisma generate | `npx prisma generate` | 성공 |

### 6-2. claude-docs 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G7 | sensor 9종 | `for s in sensor-shared-contracts sensor-server sensor-docs-sync sensor-credit-atomicity sensor-payment-idempotency sensor-payment-reconciliation sensor-admin-credit-ui sensor-refund-atomicity sensor-adversarial-pre-commit; do bash .claude/scripts/$s.sh; done` | 모두 exit 0 (PASS) |
| G8 | eval | `bash eval/scripts/eval-runner.sh` | regression 55/55 PASS, drift 0 |

### 6-3. web 검증 게이트 (변경 0건 박제)

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G9 | web 레포 git diff | `cd grimoire-web && git diff --stat develop` | 0 files changed (본 Sprint web touch 0건) |

### 6-4. Evaluator (qa) 채점 항목

- AC 7건 각각 PASS/FAIL 판정 (raw stdout 박제)
- DEV_REPORT.md `Server 섹션 §5 센서 결과` raw stdout 전문 박제 여부
- QA_REPORT.md `### sprint-pay-p1-1-refund-atomicity 통과율` 박제 (목표 7/7 = 100%)
- dev 환경 배포 후 webhook 시뮬 실제 검증 (curl raw response + psql payments/credit_logs/refund_logs/admin_audit_logs row 박제)
- 통합 테스트 §5-2 결과 박제 (정상 환수 + deficit 환수 + 멱등성 회귀 3 시나리오)
- ★ **commit/push 메인 책임 검증** — Generator(server agent)가 자율 commit/push 수행 시 즉시 FAIL 박제 (PAY-P0 회고 정합)

---

## 7. 산출물 체크리스트

### 7-1. server 산출물

- [ ] `prisma/schema.prisma` — `model RefundLog` 신설 (id/paymentId/amount/credits/deficitCredits/reason/processedAt/source + @@index([paymentId]) + @@map("refund_logs"))
- [ ] `prisma/migrations/{ts}_add_refund_log/migration.sql` — CREATE TABLE refund_logs + INDEX paymentId. INSERT seed 0건 강제.
- [ ] `src/domain/port/outbound/payment-repository.port.ts` — `refundPaymentAtomically` 시그니처 추가 (객체 인자 1개 + 반환 객체)
- [ ] `src/adapter/outbound/persistence/prisma-payment.repository.ts` — `refundPaymentAtomically` $transaction 구현 (Payment.status='refunded' + Author.credits decrement(actualDeducted, 0 fix) + CreditLog amount=-actualDeducted + RefundLog 박제)
- [ ] `src/application/payment/refund-payment.usecase.ts` — RefundPaymentUseCase 신설 (정상 환수 + deficit 분기 + AuditLogService.log('system_refund', ...) 호출)
- [ ] `src/application/payment/refund-payment.usecase.spec.ts` — ≥5 it 블록 + toHaveBeenCalledWith ≥5건 (더미 assertion 0건)
- [ ] `src/application/payment/payment.usecase.ts` — 'cancel' 분기에서 RefundPaymentUseCase.execute 호출 + 응답에 deficitCredits 포함
- [ ] `src/application/payment/payment.usecase.spec.ts` — 'cancel' / 'fail' / 'duplicate' 시나리오 회귀 spec 추가
- [ ] `src/app.module.ts` — RefundPaymentUseCase + AuditLogService DI 추가 (또는 PaymentModule 확장)
- [ ] DEV_REPORT.md Server 섹션 — sensor-server raw stdout + sensor-refund-atomicity raw stdout + jest raw stdout 박제. 통합 §5-2 수동 검증(localhost psql + curl)은 qa 단계 위임.
- [ ] `TECH_STATUS.md` (server 레포) — Payment 카테고리에 PAY-P1-1 한 줄 박제
- [ ] `CHANGELOG.md` (server 레포) — `[Unreleased]` 최상단에 Added — 환불 정밀 처리 + RefundLog 모델 박제
- [ ] `docs/data-model.md` — RefundLog 박제
- [ ] `SCHEMA.md` — RefundLog 박제
- [ ] `MIGRATION.md` — refund_logs 마이그레이션 정책 박제 (롤백 포함)
- [ ] `docs/api-contract.md` — webhook 응답 schema에 deficitCredits 추가 (선택)

### 7-2. claude-docs 산출물

- [ ] `.claude/scripts/sensor-refund-atomicity.sh` — 신설 (chmod +x, 검증 항목 ≥7건 — AC-5 정본)
- [ ] `eval/tasks/regression-55-refund-atomicity.json` — 신설 (eval_criteria ≥6건, AC-1~5 grep 명령 박제)
- [ ] `.claude/shared-contracts.md` §13 — RefundPaymentAtomically 인터페이스 박제 + 변경 이력
- [ ] `research/HARNESS_ENGINEERING.md` §14.4 — Sensors 28→29 + sensor-refund-atomicity 행 + eval task 54→55 갱신 (drift 0 박제)
- [ ] (선택) PLANNING_GRIMOIRE.md — PAY-P1-1 완료 마크 (사용자 승인 필요. Initializer 권고만)

### 7-3. web 변경 없음

- 본 Sprint는 100% server + claude-docs. web 변경 0건. Generator는 git diff로 web 레포 touch 0건 박제 의무 (§6-3 G9). 향후 PAY-P1-2 (이메일 알림) + 환불 전용 web UI는 별도 Sprint.

---

## 8. 위험 / 롤백 정책

### 8-1. 위험 항목

| # | 위험 | 영향 | 완화 |
|---|---|---|---|
| R1 | $transaction 내부 race — 동시 환불 webhook 2건 | 같은 payment 2회 환수 → 잔액 음수 가능 | PAY-P0-1 webhook event_id 멱등성 게이트 (L1) + payment.status='refunded' 사후 게이트 (L2) 3중 차단 |
| R2 | Author.credits 음수 fallthrough — decrement(credits) 시 잔액 < credits | 음수 잔액 위험 | $transaction 내부에서 SELECT FOR UPDATE → Math.min(credits, balance) 계산 → decrement(actualDeducted) 보장 |
| R3 | RefundLog 누락 + Author.credits decrement만 성공 | 추적 불가 | 단일 $transaction으로 Payment + Author + CreditLog + RefundLog 모두 묶음. 하나라도 실패 시 전체 롤백. |
| R4 | AuditLog 호출이 $transaction 외부 → DB 트랜잭션 commit 후 AuditLog 실패 | 환수는 성공했는데 추적 누락 | AuditLog는 $transaction 외부 호출 (auditLogRepo가 별도 prisma 인스턴스 사용 가능 — Generator §3-1 결정). 후행 실패 시 logger.error + DLQ 후속 (PAY-P2). 본 Sprint는 throw 0 + logger 박제 권고. |
| R5 | 'fail' webhook도 환불 처리됨 (분기 오작동) | 결제 실패 시 크레딧 환수 (적자) | 'cancel' 분기 명시적 분리 + spec it 블록 'fail' 시나리오 toHaveBeenCalledTimes(0) 검증 (AC-3) |
| R6 | RefundLog @@unique 도입 시 부분 환불 호환성 깨짐 | P2-1 부분 환불 도입 차단 | §3-7 결정 — L3 unique 미도입 권고 (L1+L2로 충분) |
| R7 | PAY-P0-1 webhook event 'failed' 박제 정합 — refund 처리 실패 시 webhook event 'processed' 박제 안 됨 | 같은 eventId 재전송 시 다시 처리 → refund 2회 시도 | refund usecase throw 시 catch → webhook event 'failed' 박제 + Polar 재전송 시 다른 eventId (또는 같은 eventId면 webhookEventRepo 'failed' 게이트로 회피 — Generator 회귀 검증) |
| R8 | docs/api-contract.md 미갱신 | client SDK 응답 schema drift | server CLAUDE.md §3 "코드 변경과 문서 변경은 같은 커밋" 정합 — Generator 의무 박제 |

### 8-2. 롤백 정책

- **코드 차원**: RefundPaymentUseCase 호출 라인 + payment.usecase.ts 'cancel' 분기 변경 → 1 commit revert. Repository 변경 + Prisma schema는 별도 revert 가능.
- **DB 차원**: `npx prisma migrate resolve --rolled-back {migration_name}` (refund_logs 테이블 DROP). 이미 박제된 RefundLog row는 손실되지만 schema 변경 0건이라 영향 0. 단 Author.credits decrement는 이미 commit되어 복원 불가 → DB dump 활용.
- **운영 차원**: PAY-P1-1 미배포 상태로 롤백 시 환불 webhook은 status='refunded' 마킹만 처리 (현재 갭 그대로). 환수는 운영자 수동 처리 필요 (백엔드 API 직접 호출 또는 PAY-P0-3 admin UI 활용).

### 8-3. 사전 백업 권장

- **DB schema 변경 1건** (refund_logs 신규) → 백업 권장 (prod 배포 전 DB snapshot).
- 본 Sprint는 기존 row 변경 0건 (신규 테이블만) → 롤백 시 데이터 손실 0건.
- 단 prod 배포 후 첫 환불 webhook 처리 시 격리 테스트 권고 (실제 Polar 환불 시뮬 → dev 환경에서 사전 검증 + raw response + psql row 박제).

---

## 9. shared-contracts §13 신설 안 (claude-docs Generator 박제 정본)

**[MUST]** claude-docs Generator는 아래 텍스트 블록을 `.claude/shared-contracts.md` `## 12. PaymentReconciliation` 섹션 직후에 박제. (PAY-P0-3에서 §13 미박제 결정 → 본 Sprint에서 처음 §13 신설)

```text
{HASH}{HASH} 13. RefundPaymentAtomically (server 도메인 — 환불 정밀 처리)

**위치**:
- UseCase: `grimoire-server/src/application/payment/refund-payment.usecase.ts`
- Port (extend): `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (refundPaymentAtomically 시그니처 추가)
- Adapter: `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` ($transaction 구현)
- DB 모델: `grimoire-server/prisma/schema.prisma` (RefundLog 신규)
- 분기 호출: `grimoire-server/src/application/payment/payment.usecase.ts` (processWebhook 'cancel' 분기)

**적용**: Polar 환불 webhook 수신 시 크레딧 환수 트랜잭션 + RefundLog + AdminAuditLog(operator='system_refund') 박제. PAY-P0-1 webhook_events 테이블이 멱등성 자동 보장.

{HASH}{HASH}{HASH} 시그니처

```typescript
// PaymentRepositoryPort 확장
refundPaymentAtomically(input: {
  paymentId: string
  authorId: string
  credits: number              // 환수 대상 (양수)
  refundedAmount: number       // 환불 금액 (KRW)
  reason: string
  source: 'webhook' | 'manual'
}): Promise<{
  actualDeducted: number       // 실제 차감된 크레딧 (deficit 시 잔액)
  deficitCredits: number       // 잔액 부족분 (정상 환수 시 0)
}>

// RefundPaymentUseCase
async execute(input: { ... 동일 시그니처 ... }): Promise<{ actualDeducted, deficitCredits }>
```

{HASH}{HASH}{HASH} DB 모델 (Prisma)

```prisma
model RefundLog {
  id             String   @id @default(uuid())
  paymentId      String   @map("payment_id")
  amount         Int                                    // 환불 금액 (KRW)
  credits        Int                                    // 실제 환수 크레딧 (actualDeducted)
  deficitCredits Int      @default(0) @map("deficit_credits")  // 잔액 부족분 (외상)
  reason         String
  processedAt    DateTime @default(now()) @map("processed_at") @db.Timestamptz(3)
  source         String                                 // 'webhook' | 'manual'

  @@index([paymentId])
  @@map("refund_logs")
}
```

{HASH}{HASH}{HASH} 정책

- **3중 멱등성**: L1 webhook event_id (PAY-P0-1) / L2 payment.status='refunded' / L3 RefundLog (선택 — P2-1 호환성 우선 미도입)
- **deficit 분기**: Author.credits < credits 시 → Author.credits=0 fix + RefundLog.deficitCredits 박제 + AuditLog(action='refund_deficit'). 음수 잔액 절대 차단.
- **정상 환수**: Author.credits >= credits → decrement(credits) + RefundLog.deficitCredits=0 + AuditLog(action='refund_normal').
- **CreditLog 음수 박제**: amount=-actualDeducted (계정 잔액 합산 정합)
- **AuditLog operator='system_refund'**: PAY-P0-2 'system_reconciliation' 패턴 정합. action='refund_normal' 또는 'refund_deficit' 분기.
- **'fail' webhook 분기 차단**: event.status='cancel' 분기에서만 refund 호출. 'fail'은 환수 대상 아님 (단순 status='failed' 갱신).

{HASH}{HASH}{HASH} 처리 흐름 (payment.usecase.processWebhook 'cancel' 분기)

1. paymentRepo.findByExternalTransactionId(tradeNo) → payment 조회 (PAY-P0-1 게이트 통과 후)
2. payment.status === 'completed' 확인 (이미 처리된 결제만 환불 가능)
3. refundPaymentUseCase.execute({ paymentId, authorId, credits, refundedAmount, reason, source: 'webhook' })
4. webhookEventRepo.createIfAbsent({ ..., status: 'processed' })
5. return { processed: true, credits: 0, deficitCredits: result.deficitCredits }

{HASH}{HASH}{HASH} 변경 시 동시 갱신 대상

- `grimoire-server/src/application/payment/refund-payment.usecase.ts` (신설)
- `grimoire-server/src/application/payment/refund-payment.usecase.spec.ts` (신설)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (refundPaymentAtomically 구현)
- `grimoire-server/src/application/payment/payment.usecase.ts` ('cancel' 분기 호출)
- `grimoire-server/src/application/payment/payment.usecase.spec.ts` (회귀 spec)
- `grimoire-server/src/app.module.ts` (RefundPaymentUseCase DI)
- `grimoire-server/prisma/schema.prisma` + `prisma/migrations/{ts}_add_refund_log/`
- `grimoire-server/docs/data-model.md` + `SCHEMA.md` + `MIGRATION.md`
- `eval/tasks/regression-55-refund-atomicity.json`
- `.claude/scripts/sensor-refund-atomicity.sh`

{HASH}{HASH}{HASH} 변경 이력
- 2026-05-03 #10_7 PAY-P1-1: 신설 — Refund 정밀 처리 + RefundLog 모델 + 3중 멱등성 (PAYMENT_SYSTEM_PLAN §3-2 PAY-P1-1 정합)
```

추가로 shared-contracts.md 마지막 줄 `마지막 업데이트:` 라인을 `2026-05-03 (§13 RefundPaymentAtomically 신설)`로 교체.

---

## 10. HANDOFF Chain

```
planner (Initializer — 본 sprint progress + PLANNER_REPORT 갱신 완료)
  ↓
cost-accountant (사전 — ✅ 면제. AI 호출 0건 + 인프라 비용 영향 0건. 본 Sprint는 100% server 트랜잭션 + DB 1 신규 테이블.)
  ↓
visual-canon-keeper (사전 — ✅ 면제. 시각 정본 변경 0건. 본 Sprint는 100% 백엔드 + claude-docs. web UI 변경 0건.)
  ↓
grimoire-server (Generator)
  - 본 progress.md §2 IN — server 14건 + §7-1 산출물 체크리스트 완수
  - DEV_REPORT.md Server 섹션 §5 raw stdout 전문 박제
  - 검증 게이트 G1~G6 모두 PASS
  - ★ commit/push 절대 금지 — 메인 책임 (PAY-P0 회고 정합). Generator는 코드 변경 + DEV_REPORT.md raw stdout 박제만.
  ↓ (병렬 가능)
grimoire-claude-docs (Generator) — 메인 또는 planner 직접 박제
  - sensor-refund-atomicity.sh + regression-55 + shared-contracts §13 박제
  - 검증 게이트 G7 + G8 PASS
  ↓
grimoire-qa (Evaluator)
  - AC 7건 raw 채점 (PASS/FAIL 박제)
  - QA_REPORT.md `### sprint-pay-p1-1-refund-atomicity 통과율` 박제
  - dev 환경 webhook 시뮬 실제 검증 (curl raw response + psql refund_logs/credit_logs/admin_audit_logs row)
  - ★ Generator 자율 commit/push 흔적 검증 (git log 확인) — 발견 시 즉시 FAIL 박제
  ↓
사용자 (배포 게이트 최종 판정 + commit/push 최종 책임)
  - qa PASS 시 commit + push 진행
  - develop → main per-repo 머지 (server + claude-docs 2 레포)
  - prod 배포 (`npx prisma migrate deploy` — refund_logs 무중단 추가, web 변경 0건이므로 Container Apps server만 재배포)
```

- **next agent**: grimoire-server (Generator) + grimoire-claude-docs (병렬) → grimoire-qa (Evaluator) → 사용자 (commit/push + 머지)
- **마감**: 본 세션 종료 전 dev 머지 (사용자 명시 — "옵션 A 채택, dev까지 진행 + 머지")
- **단일 진실**: 본 progress.md (Generator/Evaluator 모두 본 파일 Read 후 작업, 모호하면 본 파일 갱신 후 합의)
- **★ commit/push 메인 책임 명시**: PAY-P0-1/2 server agent 자율 commit/push 회고 → 본 Sprint는 Generator 코드 박제 + DEV_REPORT.md raw stdout 박제까지만. commit/push는 메인이 사용자 승인 후 일괄 진행. Generator가 자율 commit 시 즉시 FAIL.
- **★ spec 더미 assertion 금지 명시**: AC-2 grep 검증 (`toHaveBeenCalledWith|toHaveBeenCalledTimes` ≥5건). `expect(true).toBe(true)` / `expect(1+1).toBe(2)` 등 차단.

---

## 11. 참조

- `research/PAYMENT_SYSTEM_PLAN.md` §3-2 PAY-P1-1 (Refund 정밀 처리) + §1-5 #4 (갭) + §4 권장 모델 (RefundLog)
- `reports/PAYMENT_NEXT_STEPS.md` §3 옵션 A (PAY-P1-1 즉시 시급)
- `reports/sprint-pay-p0-1-webhook-event-id-idempotency-progress.md` (선행 1 — webhook event_id 멱등성)
- `reports/sprint-pay-p0-2-payment-reconciliation-cron-progress.md` (선행 2 — PG↔DB 정합성 cron + 'system_reconciliation' operator 패턴)
- `reports/sprint-pay-p0-3-admin-credit-grant-ui-progress.md` (선행 3 — admin UI)
- `grimoire-server/src/application/payment/payment.usecase.ts:55-58` ('cancel' 분기 — 현재 갭)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts:25-39` (`completePaymentAtomically` $transaction 패턴 차용)
- `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (확장 대상)
- `grimoire-server/src/application/admin/audit-log.service.ts:14-15` (`log` 시그니처 — 본 Sprint 활용)
- `grimoire-server/prisma/schema.prisma:97-105` (CreditLog) + `:387-398` (AdminAuditLog) + `:212-224` (WebhookEvent — PAY-P0-1) + `:400-414` (ReconciliationCheckpoint — PAY-P0-2 패턴 참조)
- `.claude/shared-contracts.md` §11 (PAY-P0-1 WebhookEventIdempotency) + §12 (PAY-P0-2 PaymentReconciliation) + §13 (본 Sprint 신설)
- `grimoire-server/CLAUDE.md` §9 결제/크레딧 원자성 + §3 문서 동기화
- `memory/project_session_20260503_3.md §2` (이번 세션 컨텍스트)
- `HANDOVER_NEXT_SESSION.md §1.5` (다음 세션 인계)
- 책 Ch 16 Anthropic 3-에이전트 (Initializer → Generator → Evaluator) — 묶음 II 6회차

---

**마지막 업데이트**: 2026-05-03 (PAY-P1-1 Initializer 신설 — RefundLog 모델 + 3중 멱등성 + AC 7건 + Ambiguity ≤ 0.1 + commit/push 메인 책임 + spec 더미 assertion 금지 명시)
