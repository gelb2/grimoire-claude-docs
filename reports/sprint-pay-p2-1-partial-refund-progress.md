# Sprint PAY-P2-1 부분 환불 (Partial Refund) — 정본 (sprint #10_7)

> **유형**: 결제 시스템 PAY-P2 1단계 — 부분 환불 비율 계산
> **소요**: ~2시간 (자율 진행 완료)
> **외부 API 의존**: 0건 (절대 규정 0-1 정합)
> **종료 조건**: AC-1~AC-7 모두 PASS + 회귀 차단 sensor 박제 + shared-contracts §17 + master plan §3 정합

---

## §1. 사용자 명시 트랙 진입

- **사용자 명시**: "결제시스템 고도화 쭉 진행" (2026-05-05)
- **마스터 플랜**: `reports/PAY-P2-MASTER-PLAN.md` §3 (P2-1 자율 가능 박제)
- **PAY-P1-1 호환성**: RefundLog 모델이 이미 `amount`(KRW) + `credits` 분리 설계 + UNIQUE 미부여 → 부분 환불 호환성 확보됨

---

## §2. AC (Acceptance Criteria) — 7건

### AC-1. PaymentRepositoryPort 시그니처 확장

`grimoire-server/src/domain/port/outbound/payment-repository.port.ts:79-100`

```typescript
refundPaymentAtomically(input: {
  paymentId: string
  authorId: string
  credits: number
  refundedAmount: number
  reason: string
  source: 'webhook' | 'manual'
}): Promise<{
  actualDeducted: number
  deficitCredits: number
  proportionalCredits: number  // ★ 신규
  isPartial: boolean           // ★ 신규
}>
```

**검증**: ✅ PaymentRepositoryPort에 `proportionalCredits: number` + `isPartial: boolean` 박제

### AC-2. prisma-payment.repository — 비율 계산 + 반올림 + Payment.status 분기

`grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts:117-220`

```typescript
const payment = await tx.payment.findUnique({
  where: { id: paymentId },
  select: { amount: true, status: true },
})
// validation
if (payment.amount <= 0) throw new Error(...)
if (refundedAmount <= 0) throw new Error(...)
if (refundedAmount > payment.amount) throw new Error(...)

// 비율 + 비례 크레딧
const ratio = refundedAmount / payment.amount
const isPartial = ratio < 1.0
const proportionalCredits = isPartial ? Math.floor(credits * ratio) : credits

// Payment.status 분기
await tx.payment.update({
  where: { id: paymentId },
  data: { status: isPartial ? 'partial_refunded' : 'refunded' },
})
```

**검증**:
- ✅ `ratio = refundedAmount / payment.amount` 박제
- ✅ `Math.floor(credits * ratio)` 반올림 (사용자 우호)
- ✅ `refundedAmount > payment.amount` validation
- ✅ `'partial_refunded'` / `'refunded'` 분기

### AC-3. refund-payment.usecase — refundedAmount 검증 + 4 action 매트릭스

`grimoire-server/src/application/payment/refund-payment.usecase.ts:51-130`

```typescript
if (refundedAmount <= 0) {
  throw new BadRequestException(`환불 금액은 양수여야 합니다: ${refundedAmount}`)
}

// AuditLog action 4 매트릭스 (PAY-P2-1)
const action = isPartial
  ? deficitCredits > 0 ? 'refund_partial_deficit' : 'refund_partial'
  : deficitCredits > 0 ? 'refund_deficit' : 'refund_normal'
```

**검증**:
- ✅ `refundedAmount <= 0` BadRequestException
- ✅ 4 action 매트릭스 박제 (refund_normal / _deficit / _partial / _partial_deficit)
- ✅ AuditLog detail에 `proportionalCredits` + `isPartial` 박제

### AC-4. spec — 16/16 PASS (PAY-P1-1 회귀 보존 10 + PAY-P2-1 신규 6)

`refund-payment.usecase.spec.ts` — `describe('부분 환불 (PAY-P2-1)')` 6 it:

1. ✅ 부분 환불 비율 50% (refundedAmount=2500, payment.amount=5000) — 크레딧 비례 25 차감 + action=refund_partial
2. ✅ 부분 환불 + 잔액 부족 deficit — proportionalCredits=25, 잔액 10 → actualDeducted=10 + deficit=15 + action=refund_partial_deficit
3. ✅ Math.floor 반올림 회귀 — credits=10 + ratio=0.75 → 7 차감 (7.5 floor)
4. ✅ 전액 환불 회귀 보존 — refundedAmount === payment.amount 시 isPartial=false + action=refund_normal
5. ✅ AuditLog 4 action 매트릭스 정확 분기
6. ✅ repository validation 실패 (refundedAmount > payment.amount) 시 throw 위임 + auditLog 0회

기존 7 it 모두 mockResolvedValueOnce 4 필드 확장 (proportionalCredits + isPartial=false 추가) → 회귀 보존.

### AC-5. sensor — 10 검증

`.claude/scripts/sensor-partial-refund.sh` 신설:
1. ✅ PaymentRepositoryPort proportionalCredits + isPartial 시그니처
2. ✅ payment.amount 조회 (트랜잭션 내부)
3. ✅ ratio = refundedAmount / payment.amount
4. ✅ Math.floor(credits * ratio) 반올림
5. ✅ refundedAmount > payment.amount validation
6. ✅ Payment.status 'partial_refunded' / 'refunded' 분기
7. ✅ refund-payment.usecase refundedAmount <= 0 validation
8. ✅ action 4 매트릭스
9. ✅ spec describe 부분 환불 + 6 it
10. ✅ 외부 프로젝트 인용 0건

**실행 결과**: 10/10 PASS

### AC-6. regression task — 10 criteria

`eval/tasks/regression-61-partial-refund.json` 신설.

### AC-7. 정본 갱신

- ✅ `.claude/shared-contracts.md` §17 PartialRefund 신설 (인터페이스 정본)
- ✅ `reports/PAY-P2-MASTER-PLAN.md` §3 (사전 박제됨)
- ✅ `research/HARNESS_ENGINEERING.md` Sensors §14.4 33→34 (자동 갱신)

---

## §3. 외부 프로젝트 인용 0건 검증

```bash
grep -rEi 'CERTI_PROJ|brightmall|thermage|inapi' \
  grimoire-server/src/domain/port/outbound/payment-repository.port.ts \
  grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts \
  grimoire-server/src/application/payment/refund-payment.usecase.ts \
  grimoire-server/src/application/payment/refund-payment.usecase.spec.ts
# 기대: 0건 (sensor [10/10] 통과)
```

---

## §4. 회귀 차단 정합

| sensor | 결과 | 비고 |
|---|---|---|
| sensor-partial-refund | ✅ 10/10 PASS | 신규 박제 |
| sensor-refund-atomicity | ✅ PASS | PAY-P1-1 회귀 보존 |
| sensor-payment-retry-reuse | ✅ PASS | PAY-P1-3 회귀 보존 |
| sensor-payment-idempotency | ✅ PASS | PAY-P0-1 회귀 보존 |
| jest server | ✅ 583/583 PASS | refund-payment.spec 16/16 + 기타 |
| tsc | ✅ 0 errors | strict 정합 |

---

## §5. 부분 환불 흐름 (예시)

### 정상 시나리오: 50% 부분 환불

```
사용자 결제: 5,000원 → 50 크레딧 적립
운영자 부분 환불: 2,500원 (50%)

1. Polar webhook order.refunded { amount: 2500, ... }
2. payment.usecase.processWebhook 'cancel' 분기
3. refundPaymentUseCase.execute({
     paymentId, authorId, credits: 50, refundedAmount: 2500, ...
   })
4. paymentRepo.refundPaymentAtomically:
   - payment.amount = 5000
   - ratio = 2500/5000 = 0.5
   - isPartial = true
   - proportionalCredits = Math.floor(50 * 0.5) = 25
   - status = 'partial_refunded'
   - currentBalance = 50 → actualDeducted = 25 → deficit = 0
   - Author.credits: 50 → 25 (decrement 25)
   - CreditLog: amount=-25, reason='refund_pay-1_webhook_partial'
   - RefundLog: amount=2500, credits=25, deficitCredits=0
5. AuditLog: action='refund_partial', detail.{ proportionalCredits, isPartial: true, ... }
```

### deficit 시나리오: 50% 부분 환불 + 잔액 부족

```
사용자 결제: 5,000원 → 50 크레딧 적립
사용자 사용: 40 크레딧 (잔액 10)
운영자 부분 환불: 2,500원 (50%)

1. proportionalCredits = Math.floor(50 * 0.5) = 25
2. currentBalance = 10 → actualDeducted = 10 → deficit = 15
3. Author.credits: 10 → 0 (decrement 10)
4. RefundLog: amount=2500, credits=10, deficitCredits=15
5. AuditLog: action='refund_partial_deficit'
```

---

## §6. 사용자 결정 영역

| # | 항목 | 명령 |
|---|---|---|
| 1 | dev 검증: 부분 환불 시뮬 | Polar dashboard에서 partial refund 발행 후 webhook 확인 |
| 2 | dev 검증: deficit 시나리오 | 사용자가 크레딧 일부 사용 후 부분 환불 시뮬 |
| 3 | prod 배포 | `npx prisma generate && make deploy-prod` (schema 변경 0건이므로 migrate deploy 불필요) |
| 4 | Payment.status 'partial_refunded' enum 추가 결정 | DB schema 변경 시 마이그레이션 필요. 현재는 String 컬럼이라 추가 0건. |

---

## §7. 다음 단계 — PAY-P2-2 DLQ

**진입 게이트**: 본 sprint 종료 + commit/push 직후 자동 진입.

**예상 변경**:
- WebhookRetryQueue Prisma 모델 신설 (~1줄 schema)
- WebhookRetryJob @Cron 5분 신설
- payment.usecase 실패 분기에 retry queue 박제
- spec 8 it + sensor 10 검증 + regression-62

---

## §8. 검증 명령

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire

# PAY-P2-1 회귀 검증
bash .claude/scripts/sensor-partial-refund.sh
bash eval/scripts/eval-runner.sh tasks/regression-61-partial-refund.json

# server jest 583/583 PASS
cd grimoire-server
npx jest src/application/payment/refund-payment.usecase.spec.ts

# 다른 sprint 회귀 보존
cd /Users/sokol/Desktop/Git/ProjectGrimoire
bash eval/scripts/eval-runner.sh
bash .claude/scripts/sensor-adversarial-pre-commit.sh
```

---

## §9. 정본 정합

- `.claude/shared-contracts.md` §17 PartialRefund (인터페이스 정본)
- `reports/PAY-P2-MASTER-PLAN.md` §3 (마스터 플랜 정본)
- `research/PAYMENT_SYSTEM_PLAN.md` (결제 시스템 정본)

---

마지막 업데이트: 2026-05-05 PAY-P2-1 자율 진행 완료
승격 원본: PAY-P2 마스터 플랜 §3 + 사용자 명시 "결제시스템 고도화 쭉 진행"
