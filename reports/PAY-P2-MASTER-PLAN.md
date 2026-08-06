# PAY-P2 결제 시스템 고도화 마스터 플랜 (sprint #10_7)

> **유형**: 결제 시스템 P2 단계 진입 계획서 (정본)
> **승격 원본**: 사용자 명시 "결제시스템 고도화 쭉 진행" (2026-05-05)
> **종합 시간**: ~6h (P2-1 부분환불 ~2h + P2-2 DLQ ~4h)
> **외부 의존**: 0건 (Polar만 기존, P2-3 SMS는 사용자 영역 박제)

---

## §1. PAY-P0/P1 완료 현황 (PAY-P2 진입 전)

| Sprint | 결과 | commit |
|--------|------|--------|
| PAY-P0-1 webhook event_id 멱등성 | ✅ | server `8c13103` + claude-docs `86f7487` |
| PAY-P0-2 PG↔DB 정합성 cron | ✅ | server `8e9e02e` + claude-docs `790e692` |
| PAY-P0-3 운영자 수동 크레딧 UI | ✅ | web `af3f04c` + claude-docs `841e704` |
| PAY-P1-1 Refund 정밀 처리 | ✅ | server `adfcae8` + web `eb64a8b` + claude-docs `2ed585e` |
| PAY-P1-3 retry 정책 + cleanup cron | ✅ | server `888fe2b` + web `1d924db` + claude-docs `59a33e4` |

**현 결제 시스템 안정성**:
- 멱등성 3중 게이트 (webhook_events @unique + Payment.status='completed' 사전체크 + RefundLog 박제)
- @Cron 2종 (10분 정합 검증 + 매일 4시 cleanup)
- 의미 있는 spec 78건 (PAY-P0 38 + P1-3 15 + EMAIL-P0-3 6 + EmailServicePort 8 + 기타 11)

---

## §2. PAY-P2 Sprint 분할 (3건)

| Sprint | 이름 | 자율 | 시간 | 외부 의존 | 우선 |
|--------|------|------|------|----------|------|
| **PAY-P2-1** | 부분 환불 (Partial Refund) | ✅ | ~2h | 0 | HIGH |
| **PAY-P2-2** | DLQ (Postgres RetryQueue) | ✅ | ~4h | 0 | HIGH |
| **PAY-P2-3** | SMS 알림 | ❌ | — | 1+ | BLOCKED |

---

## §3. PAY-P2-1 부분 환불 (Partial Refund) 진입 분석

### §3-1. 현재 갭

**준비 완료된 영역 (PAY-P1-1 박제 정합)**:
- ✅ RefundLog `amount Int` (PG 환불 금액 KRW) + `credits Int` (차감 크레딧) **분리 설계** (`prisma/schema.prisma:426-427`)
- ✅ RefundLog UNIQUE 미부여 — **부분 환불 호환성 확보** (`schema.prisma:435`)
- ✅ RefundPaymentUseCase 입력 `refundedAmount` 별도 박제 (`refund-payment.usecase.ts:40-50`)
- ✅ Polar webhook `order.refunded` 파싱 amount 추출 (`polar.adapter.ts:163-171`)

**잔존 갭**:
- ⚠️ `refundPaymentAtomically` (`prisma-payment.repository.ts:148`) — `actualDeducted = Math.min(currentBalance, credits)` 전액 가정. 부분 환불 비율 계산 0건.
- ⚠️ Payment.amount (원래 결제 금액) 조회 후 `refundedAmount / paymentAmount` 비율 계산 누락
- ⚠️ deficit 분기는 비율 적용 후에도 동일하게 적용되어야 (잔액 부족 우선)

### §3-2. 변경 설계 (~20줄)

#### §3-2-1. RefundPaymentUseCase 입력 확장

```typescript
// refund-payment.usecase.ts 입력 시그니처
async execute(input: {
  paymentId: string
  authorId: string
  credits: number              // 원래 결제 시 적립한 크레딧 (전체)
  refundedAmount: number       // ★ 신규 의미: 부분 환불 금액 (전체 = 전액 환불)
  reason?: string
  source: 'system_refund' | 'admin_manual'
}): Promise<RefundResult>
```

**의미 변경 0** — `refundedAmount`는 이미 박제됨. UseCase 내부 활용 강화만.

#### §3-2-2. 환수 계산 로직 (`prisma-payment.repository.ts:148`)

```typescript
// 기존 (전액 가정)
const actualDeducted = Math.min(currentBalance, credits)
const deficitCredits = Math.max(0, credits - currentBalance)

// 신규 (부분 환불 비율)
const payment = await tx.payment.findUnique({ where: { id: paymentId } })
const ratio = refundedAmount / payment.amount  // 0.0 ~ 1.0
const proportionalCredits = Math.floor(credits * ratio)  // 반올림 정책: floor (사용자 우호)
const actualDeducted = Math.min(currentBalance, proportionalCredits)
const deficitCredits = Math.max(0, proportionalCredits - currentBalance)
```

**정책 결정**:
- **반올림**: `Math.floor` 고정 — 사용자 우호 (소수점 버림으로 차감 ↓)
- **비율 ≥ 1.0**: 전액 환불 (정상)
- **비율 < 0**: 차단 (검증 추가)
- **payment.amount = 0** (free): 차단 (refundedAmount > 0 의미 없음)

### §3-3. spec 추가 (+6 it)

```typescript
describe('RefundPaymentUseCase 부분 환불 (PAY-P2-1)', () => {
  it('부분 금액 (전체 50%) → 크레딧 50% 비례 차감')
  it('부분 환불 + 잔액 부족 → proportional credits만큼만 deficit 계산')
  it('부분 환불 후 추가 부분 환불 → 누적 비율 정상 차감')  // 다중 부분 환불 시나리오
  it('refundedAmount === payment.amount → 전액 환불 회귀 보존 (PAY-P1-1 정합)')
  it('refundedAmount > payment.amount → BadRequestException (validation)')
  it('Math.floor 반올림 — refundedAmount/amount * credits = 7.5 → 7 차감')
})
```

### §3-4. AC (Acceptance Criteria) — 5건

1. ✅ refundPaymentAtomically의 비율 계산 박제 (`Math.floor(credits * ratio)`)
2. ✅ payment.amount 조회 후 ratio 계산 (트랜잭션 내부)
3. ✅ refundedAmount > payment.amount 시 BadRequestException (validation)
4. ✅ spec 6 it 추가 + 16/16 → 22/22 PASS
5. ✅ 회귀 보존: PAY-P1-1 전액 환불 spec 모두 PASS (RefundPaymentUseCase 38 spec)

### §3-5. sensor + regression task

- 신규 `sensor-partial-refund.sh` (8 검증)
  1. ratio 계산 패턴 박제
  2. Math.floor 반올림 박제
  3. payment.amount 조회 박제
  4. refundedAmount > amount validation 박제
  5. spec 부분 환불 describe 박제
  6. spec deficit + 부분 시나리오 박제
  7. 외부 프로젝트 인용 0건
  8. 의미 있는 assertion ≥6건
- 신규 `regression-61-partial-refund.json` (10 criteria)
- shared-contracts §17 PartialRefund 신설

---

## §4. PAY-P2-2 DLQ (Postgres RetryQueue) 진입 분석

### §4-1. 현재 갭

**현 webhook 실패 처리** (payment.usecase.ts):
- L86-87: invalid_or_ignored → 200 + processed:false (재시도 안 됨)
- L96-108: tradeNo 미존재 → skipped (재시도 안 됨)
- L109-120: 이미 완료 → skipped (재시도 안 됨)
- **L125-138**: completePaymentAtomically 실패 → webhook_events 'failed' + throw (Polar 자체 retry 의존)
- **L159-180**: refund 실패 → webhook_events 'failed' + throw (Polar 자체 retry 의존)

**잔존 위험**:
- ⚠️ Polar 자체 retry 횟수 미명시 (3~5회 추정) → 초과 시 영구 손실
- ⚠️ 운영자가 실패 webhook을 명시 재처리할 수단 0건
- ⚠️ DB 일시 장애 시 재시도 백오프 0 → 즉시 실패

### §4-2. 변경 설계 (~50줄)

#### §4-2-1. Prisma schema 추가

```prisma
model WebhookRetryQueue {
  id          String   @id @default(uuid())
  eventId     String   @unique             // Polar webhook-id (멱등성 통합)
  payload     Json                          // NormalizedWebhookEvent 전체
  retryCount  Int      @default(0)
  lastError   String?
  nextRetryAt DateTime @default(now())     // exp backoff: 1m → 5m → 30m → 2h → 12h → 24h
  createdAt   DateTime @default(now())
  
  @@index([nextRetryAt])
  @@map("webhook_retry_queues")
}
```

#### §4-2-2. WebhookRetryJob 신규 (@Cron 5분)

```typescript
@Injectable
export class WebhookRetryJob {
  @Cron('*/5 * * * *')  // 5분마다
  async run() {
    if (this.isRunning) return  // lock
    this.isRunning = true
    try {
      const due = await this.queueRepo.findDue(100)  // nextRetryAt <= now() LIMIT 100
      for (const item of due) {
        try {
          await this.paymentUseCase.processWebhook(item.payload)
          await this.queueRepo.delete(item.id)  // 성공 시 제거
        } catch (err) {
          await this.queueRepo.markRetry(item.id, err.message, this.calcNextRetry(item.retryCount + 1))
          if (item.retryCount >= 9) {  // 최대 10회
            await this.markPermanentFailed(item.eventId, err.message)
          }
        }
      }
    } finally {
      this.isRunning = false
    }
  }
  
  private calcNextRetry(count: number): Date {
    const minutes = [1, 5, 30, 120, 720, 1440, 1440, 1440, 1440, 1440][count] ?? 1440
    return new Date(Date.now() + minutes * 60_000)
  }
}
```

#### §4-2-3. payment.usecase.processWebhook 보강

```typescript
// L125-138 (success 분기 실패 시)
} catch (err) {
  // 기존: webhook_events 'failed' 박제 + throw
  await this.webhookEventRepo.markFailed(eventId, err.message)
  // 신규: retry queue 박제 (멱등성 — eventId UNIQUE)
  await this.retryQueueRepo.upsert({
    eventId,
    payload: normalizedEvent,
    nextRetryAt: new Date(Date.now() + 60_000),  // 1분 후 첫 재시도
  })
  throw err
}
```

### §4-3. spec 추가 (+8 it)

```typescript
describe('WebhookRetryJob (PAY-P2-2)', () => {
  it('nextRetryAt 도래한 row만 처리')
  it('성공 시 row 삭제')
  it('실패 시 retryCount++ + 백오프 스케줄 갱신')
  it('최대 재시도 (10회) 초과 시 permanent_failed 박제')
  it('isRunning lock — 동시 실행 차단')
  it('다중 row 순차 처리 (LIMIT 100)')
  it('UNIQUE 충돌 시 createdAt 보존')
  it('AdminAuditLog operator=system_dlq 박제')
})
```

### §4-4. AC — 7건

1. ✅ WebhookRetryQueue Prisma 모델 + migration
2. ✅ WebhookRetryJob @Cron 5분 + isRunning lock
3. ✅ exp backoff (1m → 5m → 30m → 2h → 12h → 24h)
4. ✅ retryCount > 10 시 permanent_failed 박제
5. ✅ payment.usecase.processWebhook 실패 시 retry queue 박제 (멱등성)
6. ✅ AdminAuditLog operator='system_dlq' 박제 (운영자 추적용)
7. ✅ spec 8 it 추가 + 회귀 보존

### §4-5. sensor + regression task

- 신규 `sensor-webhook-dlq.sh` (10 검증)
- 신규 `regression-62-webhook-dlq.json` (12 criteria)
- shared-contracts §18 WebhookDLQ 신설

---

## §5. PAY-P2-3 SMS 알림 (BLOCKED — 사용자 영역)

**진입 게이트**: 절대 규정 0-1 (외부 API 신규 의존 보류) **해제 결정 사용자 명시**

**참고 솔루션**:
- **KAKAO Bizmessage** (KRW 결제, 친구톡/알림톡) — 추천 (한국 사용자 중심)
- NHN Cloud SMS (한국 SMS 표준)
- Twilio (USD 결제, 글로벌)

**진입 시 작업 영역** (자율 가능 영역만):
1. SMS 발송 Hexagonal Port 캡슐화 (NullSmsAdapter stub) — 외부 API 결정 전 작업 가능
2. 결제 완료 시 SMS 발송 트리거 코드 (NullAdapter는 noop) — 작업 가능
3. spec + sensor + regression task — 작업 가능
4. 실 SMS adapter 구현 (KakaoBizmessageAdapter / NhnCloudAdapter / TwilioAdapter) — **사용자 결정 후만**

**EmailServicePort 패턴 정합** — 이메일과 동일하게 Port 캡슐화 + NullAdapter stub 우선 박제 가능.

---

## §6. 의존성 그래프

```
PAY-P0/P1 (✅ 종료)
  ↓
PAY-P2-1 부분 환불 (자율, ~2h)
  ├─ RefundLog 호환 (이미 준비)
  ├─ refundPaymentAtomically 비율 보강
  └─ spec 6 it + sensor + regression-61
  ↓
PAY-P2-2 DLQ (자율, ~4h)
  ├─ WebhookRetryQueue 신규 모델 + migration
  ├─ WebhookRetryJob 신규 @Cron
  ├─ payment.usecase 실패 분기 보강
  └─ spec 8 it + sensor + regression-62
  ↓
PAY-P2-3 SMS (BLOCKED, 사용자 결정)
  ├─ SmsServicePort 캡슐화 (자율 가능)
  ├─ NullSmsAdapter stub (자율 가능)
  └─ 실 SaaS adapter (사용자 결정 후)
```

---

## §7. 진입 순서 + 검증 명령

### 진입 순서

1. **본 마스터 플랜 박제** ← 현재 단계
2. PAY-P2-1 부분 환불 sprint 진입 → commit → push (자율)
3. PAY-P2-2 DLQ sprint 진입 → commit → push (자율)
4. PAY-P2-3 진입 결정 받기 (사용자 외부 API 결정 게이트)

### 검증 명령

```bash
# PAY-P2-1 진입 후
bash .claude/scripts/sensor-partial-refund.sh
bash eval/scripts/eval-runner.sh tasks/regression-61-partial-refund.json
cd grimoire-server && npx jest src/application/payment/refund-payment.usecase.spec.ts

# PAY-P2-2 진입 후
bash .claude/scripts/sensor-webhook-dlq.sh
bash eval/scripts/eval-runner.sh tasks/regression-62-webhook-dlq.json
cd grimoire-server && npx jest src/application/payment/webhook-retry.job.spec.ts

# 종합 회귀 (P2 종료 후)
cd /Users/sokol/Git/ProjectGrimoire
bash eval/scripts/eval-runner.sh
bash .claude/scripts/sensor-adversarial-pre-commit.sh
bash .claude/scripts/sensor-harness-self-diagnose.sh
```

---

## §8. 인벤토리 변동 (P2-1 + P2-2 누적 예상)

- Sensors **33 → 35** (+2: partial-refund, webhook-dlq)
- shared-contracts **§16 → §18** (+2: PartialRefund, WebhookDLQ)
- Eval regression **59 → 61** (+2: regression-61, regression-62)
- jest server **576 → ~590** (+14 신규 spec — partial 6 + dlq 8)
- DB 모델 +1 (WebhookRetryQueue)
- @Cron Job +1 (WebhookRetryJob 5분 주기)

---

## §9. 사용자 결정 영역 (PAY-P2 종료 후)

| # | 항목 | 명령 |
|---|---|---|
| 1 | dev 검증: 부분 환불 — Polar 환불 시뮬 | `curl POST polar webhook with partial refunded_amount` |
| 2 | dev 검증: DLQ — webhook 실패 시뮬 | DB 임시 장애 발생 + WebhookRetryJob 5분 후 처리 박제 |
| 3 | prod 배포 | `npx prisma generate && npx prisma migrate deploy && make deploy-prod` |
| 4 | PAY-P2-3 진입 결정 | "SMS 진입" + 외부 API 1택 (KAKAO Bizmessage 추천) |
| 5 | main per-repo 머지 (server / web / claude-docs 명시 필요) | `"server main 머지" / "web main 머지" / "claude-docs main 머지"` |

---

## §10. 정본 정합

- `research/PAYMENT_SYSTEM_PLAN.md` — 결제 정밀 진단 정본 (P0~P3 단계 박제)
- `reports/PAYMENT_NEXT_STEPS.md` — 결제 다음 단계 정본 (별도)
- `.claude/shared-contracts.md` §11~§14 (PAY-P0/P1 박제) — 본 sprint로 §17~§18 추가 예정
- `HANDOVER_NEXT_SESSION.md` §1.5 다음 트랙 J — 본 마스터 플랜으로 정밀 분할 박제

---

마지막 업데이트: 2026-05-05 트랙 G+F 완료 후 사용자 명시 결제 고도화 진입 직전 박제
승격 원본: 사용자 명시 "결제시스템 고도화 쭉 진행" + Explore subagent 정밀 조사 결과 박제
