# Sprint PAY-P3-A — Race Condition 해소 (구멍-A + 구멍-B 동시 차단, Draft, PP-13 화이트리스트 영역)

> **작성**: 2026-05-08 #10_8 본 세션 grimoire-planner agent (Initializer 역할, 책 Ch 16 Anthropic 3-에이전트 패턴 정합)
> **트리거**: 사용자 명시 — "결제 고도화 계획부터 세우고 시작해" (Auto mode 활성, 자율 진행). 마스터 플랜 §3-1 Phase 1 첫 진입 sprint 권장 정합.
> **본 위치**: `.claude/state/` (PP-13 메인 화이트리스트 우회 영역). 정본 영역(`reports/sprint-pay-p3-a-race-condition-progress.md`)으로 사용자 또는 grimoire-server agent 위임 후 이동 영역.
> **정본 위치 (예정)**: `reports/sprint-pay-p3-a-race-condition-progress.md` — Initializer 산출물, Generator(server agent)가 본 progress.md 갱신, Evaluator(qa)가 채점 대상 영역.

---

## §0 한 줄 요약

PAYMENT_AUDIT §1 구멍-A (eventId 다른 type 동시 처리 누락) + 구멍-B (transaction race — `Author.findUnique` 후 decrement, READ COMMITTED 격리 수준 race window) 동시 차단을 위해 (1) `processNormalizedWebhook` 진입에 `payment.status='refunded' OR partial_refunded` 사전 게이트 추가 + (2) `refundPaymentAtomically` $transaction 내부 `findUniqueOrThrow + updateMany WHERE credits >= actualDeducted` 원자 패턴 적용. DB schema 변경 0건 + 외부 API 0건 + 의존성 0건. 예상 ~5h. shared-contracts §22 PaymentRaceCondition 신설.

---

## §1 배경 — PAYMENT_AUDIT §1 구멍-A/B raw 인용 + 결제 적자 위험 분석

### 1-1. 구멍-A raw 인용 (PAYMENT_AUDIT §1)

> | **구멍-A** Race condition: 동일 eventId 다른 type 처리 누락 | 결제 완료 후 빠른 환불/취소 누락 | `payment.usecase.ts:147-160` `processNormalizedWebhook` 진입 시 existing 체크 = `status='processed'`만, payment.status='completed'도 체크 필요 | existing.status `OR` payment.status='completed' 동시 체크 | P1 |

**메인 정밀 검증 (직접 Read 결과)**:
- `payment.usecase.ts:156-160` `existing.status === 'processed'` 체크 ✅ (eventId 멱등성 L1)
- `payment.usecase.ts:175-186` `payment.status === 'completed'` 체크 ✅ (약식 게이트 L2)
- **누락 영역 (구멍-A 본질)**: `payment.status === 'refunded' OR 'partial_refunded'` 사전 체크 부재 → 환불 완료된 payment에 다른 eventId의 succeeded webhook 진입 시 (Polar 자체 복원 메커니즘 또는 PG 데이터 정합 오류 시나리오) **재차감 가능성 0건 보장 안 됨**
- **추가 발견 (메인 직접 Read)**: `event.status === 'cancel'` 분기는 `payment.status === 'completed'` 게이트 통과 시점에만 진입하므로 정상이지만, **이미 환불 진행 중 (refunded 또는 partial_refunded) 시 두 번째 'cancel' webhook이 들어오면**? 현재 코드에서는 `processNormalizedWebhook` 진입 → `payment.status === 'completed'` 체크 통과 안 됨 → `already_completed` skip 응답 → **정합** ✅. 단, `'partial_refunded'` 상태에서 추가 부분 환불 시 (PG가 두 번 부분 환불을 보낸다면) → `payment.status` 체크 통과 안 되어 skip. **추후 부분 환불 누적 시나리오 = §3-AC-3 보강 영역**

### 1-2. 구멍-B raw 인용 (PAYMENT_AUDIT §1)

> | **구멍-B** Transaction boundary: refund 시 Author.findUnique race | 동시 환불 → 잔액 중복 차감 가능 | `prisma-payment.repository.ts:144-199` $transaction 내 findUnique 후 decrement, lock 부재 | `SELECT ... FOR UPDATE` 또는 `findUniqueOrThrow + updateMany` 원자 재구성 | P1 |

**메인 정밀 검증 (직접 Read 결과)**:
- `prisma-payment.repository.ts:179-198` `tx.author.findUnique` (READ) → `actualDeducted = Math.min(currentBalance, proportionalCredits)` 계산 → `tx.author.update decrement` (WRITE)
- **race window**: Postgres 기본 격리 수준은 READ COMMITTED. $transaction 내부라도 다른 트랜잭션이 같은 `author.credits`를 동시에 update 시 → 본 트랜잭션의 READ는 stale snapshot, WRITE는 실제 현재값에 decrement 적용 → **잔액 inconsistency 발생 가능**
- **재현 시나리오**: 동시 환불 webhook 2건 (각 60 credits 환불, 잔액 100) → 둘 다 READ 100 → 둘 다 actualDeducted=60 → 둘 다 decrement 60 → 잔액 -20 (음수) 또는 0 fix는 트랜잭션 외부 로직만 적용 → **음수 잔액 또는 deficit 누락 가능**
- **권장 패턴**: `findUniqueOrThrow + updateMany WHERE credits >= actualDeducted` (Postgres atomic CAS — 조건 미충족 시 0 row 갱신 → throw retry)

### 1-3. 결제 적자 위험 분석 (cost-accountant 면제 영역, 자체 분석)

| 시나리오 | 영향 | 적자 영향 |
|---|---|---|
| 구멍-A 미차단 + Polar 데이터 정합 오류 (refunded 후 succeeded 재전송) | 환불 후 재차감 → 사용자 잔액 +X 추가 | 적자 X (사용자 우호 — 단, 운영자 수동 환수 부담) |
| 구멍-B 미차단 + 동시 환불 race | 잔액 중복 차감 → 사용자 잔액 -X (음수 잔액 시 0 fix 트리거 0건 보장 안 됨) | **직접 적자 가능** (deficit 누락 → 사용자가 X credits 더 많이 사용 가능) |
| 구멍-B 미차단 + 동시 결제 + 환불 (race) | 결제 increment 누락 + 환불 decrement 적용 → 사용자 잔액 -X | **직접 적자** (환불 받았는데 결제 크레딧 없는 상태) |
| 본 sprint 차단 적용 후 | $transaction 원자성 + atomic CAS + status 게이트 | 적자 위험 **0건** |

**결제 적자 위험 영역 1순위** (마스터 플랜 §3-1 권장 정합) — 본 sprint = 결제 9 sprint 완료 후 잔여 갭 중 **가장 직접적 금전 영향 영역** 우선 차단.

### 1-4. 결제 9 sprint 완료 후 잔여 갭 중 본 sprint 위치 (마스터 플랜 §2 정합)

| Sprint | 시간 | 외부 API | 의존성 | 우선순위 | 영향 |
|---|---|---|---|---|---|
| **PAY-P3-A** (본 sprint) | ~5h | 0 | 0 | **P1 (적자 위험 1순위)** | 직접 금전 |
| PAY-P3-B Polar timeout | ~2h | 0 | 0 | P1 | 운영 안정 |
| PAY-P3-C retry 중복 | ~2h | 0 | 0 | P1 | DB 정합성 |
| PAY-P3-D Status enum | ~2h | 0 | 0 | P2 | 추적 일관성 |
| PAY-P3-E FK cascade | ~3h | 0 (DB 마이그레이션) | 0 | P1 | 데이터 정합성 |
| PAY-P3-H Circuit breaker | ~4h | 0 | 0 | P1 | 가용성 |
| PAY-P2-5 audit retention | ~3h | 0 | 0 | P0 | 운영 |

---

## §2 목표 — race condition 0건 + 환불 잔액 중복 차감 0건 + incident-log 박제 의무

### 2-1. 핵심 KPI

1. **race condition 0건**: 구멍-A + 구멍-B 동시 차단 후 sensor + jest spec + eval task 자동 검증 PASS
2. **환불 잔액 중복 차감 0건**: 동시 환불 webhook 2건 시뮬에서 `Author.credits` 정확 (CAS 패턴 검증)
3. **회귀 차단 0건**: 기존 9 sprint 시나리오 (eval regression-52~65) 회귀 0
4. **incident-log 박제 의무 (Mitchell Ghostty 정합, sensor-adversarial-pre-commit P20 정합)**: sprint 진행 중 발견하는 모든 결함/우회/거짓 보고 즉시 박제 (5/8 본 세션 박제 정합)
5. **dev 작동 검증** (메인 자율 영역): 구멍-A + 구멍-B 시뮬 spec PASS는 코드 spec만, 실제 dev curl 또는 race 시뮬은 사용자 영역 또는 자동 sensor 영역

### 2-2. 비목표 (사용자 결정 영역 분리)

- ❌ Polar SDK timeout 정책 (PAY-P3-B 분리, ~2h)
- ❌ retry job 중복 해소 (PAY-P3-C 분리, ~2h)
- ❌ status enum mapping table (PAY-P3-D 분리, ~2h)
- ❌ FK cascade 정책 + DB 마이그레이션 (PAY-P3-E 분리, ~3h)
- ❌ Circuit breaker (PAY-P3-H 분리, ~4h)
- ❌ DB schema 변경 (advisory_lock 또는 partial unique index — P2 보류)
- ❌ replicas ≥2 시점 advisory_lock (현재 replicas=1 정합)

---

## §3 변경 영역 (server agent Generator 진입 정본)

### 3-1. 핵심 코드 변경 (server)

| 파일 | 변경 영역 | 영향 |
|---|---|---|
| `src/application/payment/payment.usecase.ts` | `processNormalizedWebhook` 진입 게이트 보강 — `payment.status === 'refunded' OR 'partial_refunded'` 사전 체크 추가 (L186 약식 게이트와 동일 위치) | 구멍-A 차단 |
| `src/application/payment/payment.usecase.ts` | `processWebhook` 분기 정합 (verify 후 processNormalizedWebhook 호출 → 자동 적용) | 자동 정합 |
| `src/application/payment/refund-payment.usecase.ts` | refundPaymentAtomically 호출부 정합 검증 (변경 영역 0 또는 try/catch 보강만) | 호출자 정합 |
| `src/adapter/outbound/persistence/prisma-payment.repository.ts` | `refundPaymentAtomically` $transaction 내부 race 차단 — `findUniqueOrThrow + updateMany WHERE credits >= actualDeducted` CAS 패턴 적용. 0 row 갱신 시 `throw new Error('CAS_MISMATCH')` → 호출자 retry 위임 | 구멍-B 차단 |
| `src/adapter/outbound/persistence/prisma-payment.repository.ts` | `completePaymentAtomically` 동일 패턴 권장 평가 — 결제 increment는 race window 작아도 정합 보강 권장 | 보강 영역 (선택, AC-7 영향) |

### 3-2. 신설 파일

| 파일 | 영역 |
|---|---|
| `src/application/payment/payment.usecase.spec.ts` 갱신 | 구멍-A 차단 시나리오 spec 신설 (≥ 3 it) |
| `src/application/payment/refund-payment.usecase.spec.ts` 갱신 | 구멍-B 차단 시나리오 spec 신설 (≥ 3 it) |
| `src/adapter/outbound/persistence/prisma-payment.repository.spec.ts` 신설 또는 갱신 | $transaction CAS 패턴 검증 (≥ 2 it, integration 또는 unit) |
| `eval/tasks/regression-66-payment-race-condition.json` 신설 | 8 검증 (AC 8건 정합) |
| `.claude/scripts/sensor-payment-race-condition.sh` 신설 | CAS 패턴 grep + payment.status 사전 게이트 grep |
| `.claude/shared-contracts.md §22` 신설 | PaymentRaceCondition 인터페이스 정본 박제 |

### 3-3. 변경 시 동시 갱신 대상 (책 Ch 16 shared-contracts 정합)

- `grimoire-server/docs/api-contract.md` — webhook 처리 상태 표 (refunded 상태 사전 게이트 박제)
- `grimoire-server/docs/data-model.md` — Payment status enum (refunded / partial_refunded 사전 게이트 명시)
- `grimoire-server/SCHEMA.md` — Payment status 7가지 정합 박제
- `grimoire-server/SECURITY.md §3` — 결제 원자성 영역 본 sprint CAS 패턴 박제
- `grimoire-server/ADR.md` — 결제 race condition 차단 결정 박제 (옵션 A — DB schema 변경 0건)
- `.claude/shared-contracts.md §22` — PaymentRaceCondition 신설 (본 sprint 핵심)
- `eval/tasks/regression-66-*.json`
- `.claude/scripts/sensor-payment-race-condition.sh`

### 3-4. 변경 0건 영역 (회귀 차단)

- `prisma/schema.prisma` (DB schema 변경 0건 — advisory_lock + partial unique index P2 보류)
- `src/application/payment/payment-reconciliation.job.ts` (PAY-P0-2 회귀 0)
- `src/application/payment/webhook-retry.job.ts` (PAY-P2-2 회귀 0 — `processNormalizedWebhook` 호출자, 게이트 추가는 자동 정합)
- `src/application/payment/payment-cleanup.job.ts` (PAY-P1-3 회귀 0)
- 인프라 변경 (Azure Container Apps, replicas, env 등) 0건

---

## §4 AC BDD 8건 (qa Evaluator 채점 대상)

### AC-1: 구멍-A 차단 — payment.status='refunded' 상태에서 succeeded webhook 재진입 skip

```yaml
GIVEN payment.status='refunded' (PAY-P1-1 환불 완료) + WebhookEvent eventId='evt_succeeded_old' status='processed' 박제
WHEN Polar가 데이터 정합 오류로 다른 eventId='evt_succeeded_new' type='order.succeeded' webhook 재전송
THEN processNormalizedWebhook 진입 → payment.status='refunded' 사전 게이트 통과 안 됨
  → completePaymentAtomically 호출 0건
  → webhookEventRepo.createIfAbsent { status: 'skipped', errorMessage: 'already_refunded' } 박제
  → return { processed: false, reason: 'already_refunded' }
  → Author.credits 변동 0건 (재차감 0)
```

### AC-2: 구멍-A 차단 — payment.status='partial_refunded' 상태에서 추가 partial refund webhook 진입 skip

```yaml
GIVEN payment.status='partial_refunded' (PAY-P2-1 부분 환불 완료) + WebhookEvent 1건 박제
WHEN Polar 추가 부분 환불 webhook (다른 eventId, type='order.refunded') 재전송
THEN payment.status='partial_refunded' 사전 게이트 통과 안 됨
  → refundPaymentAtomically 호출 0건
  → webhookEventRepo.createIfAbsent { status: 'skipped', errorMessage: 'already_partial_refunded' } 박제
  → return { processed: false, reason: 'already_partial_refunded' }
  → Author.credits 변동 0건
```

> **결정 게이트 (Generator 영역)**: PAY-P3-A 본 sprint에서는 partial_refunded 상태 추가 부분 환불 0건 보장이 핵심. 누적 부분 환불 정책은 PAY-P2-1 (이미 완료) 또는 별도 sprint에서 결정. 본 sprint = "partial_refunded 진입 후 추가 webhook은 무조건 skip" 단순 정책.

### AC-3: 구멍-B 차단 — 동시 환불 webhook 2건 race 시 잔액 중복 차감 0건

```yaml
GIVEN payment.status='completed' + Author.credits=100 + payment.credits=60 + payment.amount=10000
WHEN Polar webhook order.refunded eventId='evt_A' + 동시 동일 paymentId 다른 eventId='evt_B' 동시 진입 (Promise.all 시뮬)
THEN
  - eventId 멱등성 L1 (webhook_events @unique) 차단 → 둘 중 하나만 진입 (다른 하나는 P2002 → skip)
  - 만약 다른 eventId라면 (PG가 같은 환불을 두 eventId로 보낸 시나리오):
    - 첫 트랜잭션: payment.status='refunded' 갱신 + Author.credits=40 (decrement 60)
    - 두 번째 트랜잭션: payment.status='refunded' 사전 게이트 (AC-1) 통과 안 됨 → skip
  - Author.credits 최종 = 40 (정확, 중복 차감 0)
  - $transaction 내부 CAS 패턴 (`findUniqueOrThrow + updateMany WHERE credits >= 60`) 적용 검증
```

### AC-4: 구멍-B 차단 — CAS mismatch 시 throw + 호출자 retry 위임

```yaml
GIVEN payment.status='completed' + Author.credits=50 (의도적 동시 update 시뮬 — 다른 트랜잭션이 credits=10으로 미리 변경)
WHEN refundPaymentAtomically input.credits=60 호출 (잔액 부족 분기 + race window 시뮬)
THEN
  - tx.author.findUniqueOrThrow → currentBalance=10 (의도적 시뮬, 실제는 race window)
  - actualDeducted = Math.min(10, 60) = 10
  - deficitCredits = Math.max(0, 60 - 10) = 50
  - tx.author.updateMany WHERE credits >= 10 → 1 row 갱신 ✅
  - return { actualDeducted: 10, deficitCredits: 50 }
  - **CAS mismatch 케이스**: WHERE credits >= 60 에서 실제 잔액이 50으로 변경된 시점 → 0 row 갱신 → throw 'CAS_MISMATCH' → 호출자(refund-payment.usecase) catch → webhookEventRepo 'failed' 박제 → DLQ enqueue (PAY-P2-2 retry 위임)
```

### AC-5: 회귀 차단 — 기존 9 sprint 시나리오 회귀 0건

```yaml
GIVEN 기존 PAY-P0-1/P0-2/P0-3/P1-1/P1-3/P2-1/P2-2/P2-3/P2-4 8 it 시나리오
WHEN 본 sprint 변경 후 동일 시나리오 재실행 (jest server 625+ + eval regression-52~65)
THEN
  - jest 625/625+ PASS (구멍-A/B 차단으로 회귀 0)
  - eval regression-52 (webhook event_id 멱등성) PASS
  - eval regression-53 (payment reconciliation) PASS
  - eval regression-54 (admin grant credits) PASS
  - eval regression-55 (refund atomicity) PASS
  - eval regression-57 (payment retry reuse) PASS
  - eval regression-58~65 (PAY-P2-1/2/3/4) PASS
```

### AC-6: 보안 — payment.status 사전 게이트 우회 불가 (Direct Repository 호출 차단)

```yaml
GIVEN 악의적 코드 또는 회귀 변경으로 processNormalizedWebhook 진입 게이트 우회 시도
WHEN refundPaymentAtomically를 직접 호출 (payment.usecase 우회)
THEN
  - $transaction 내부 payment.findUnique → status === 'refunded' 또는 'partial_refunded' 체크
  - 통과 안 되면 throw new Error('PAYMENT_ALREADY_REFUNDED')
  - 호출자 catch → webhookEventRepo 'failed' 박제 + 로깅
  - Author.credits 변동 0건
  - sensor-adversarial-pre-commit P16 (결제 원자성) FAIL 차단 정합
```

### AC-7: 성능 — 100 동시 환불 시뮬 race window 검증

```yaml
GIVEN payment 100건 (각 status='completed', credits=60, amount=10000) + Author 100명 (각 credits=100)
WHEN 100 환불 webhook 동시 처리 (Promise.all)
THEN
  - 각 author 잔액 = 40 (정확, race condition 0건)
  - $transaction commit 100건 정상
  - jest spec timeout < 10s (배치 처리 기준)
  - completePaymentAtomically (선택 보강 시): 100건 increment 정확
  - 자원 leak 0건 (trx 누수, FD 누수)
```

### AC-8: 운영 — incident-log 박제 + AuditLog operator='system_payment' 정합

```yaml
GIVEN 구멍-A 시도 발견 (payment.status='refunded' 상태에서 succeeded webhook 진입)
WHEN payment.usecase가 게이트 차단
THEN
  - logger.warn `[PaymentRaceCondition] already_refunded eventId=evt_succeeded_new paymentId=...` 박제
  - webhookEventRepo.createIfAbsent { status: 'skipped', errorMessage: 'already_refunded' }
  - **incident-log 박제** (sensor-adversarial-pre-commit P20 정합):
    ```bash
    bash .claude/scripts/incident-log.sh \
      --category=race_condition_blocked \
      --severity=info \
      --source=payment-usecase \
      --description="구멍-A 차단 — payment.status=refunded 상태에서 succeeded webhook 시도 차단"
    ```
  - dev cron logs 박제 (PAYMENT_AUDIT §5-2 정합)
```

---

## §5 검증 매트릭스 (Generator + Evaluator 공동 영역)

### 5-1. jest server spec 신설 (≥ 6 it)

| spec | it 수 | 영역 |
|---|---|---|
| `payment.usecase.spec.ts` 갱신 | ≥ 3 | AC-1 (refunded skip) + AC-2 (partial_refunded skip) + AC-6 (보안 — 직접 호출 차단) |
| `refund-payment.usecase.spec.ts` 갱신 | ≥ 2 | AC-3 (동시 환불 race 차단) + AC-4 (CAS mismatch retry) |
| `prisma-payment.repository.spec.ts` 신설 또는 갱신 | ≥ 1 | AC-7 (100 동시 시뮬, integration 또는 unit + Promise.all) |

**예상 spec 인벤토리 변동**: 625 (sprint 진입 직전) → **631+ it** (jest server)

### 5-2. eval regression-66 신설

```json
{
  "id": "regression-66-payment-race-condition",
  "category": "regression",
  "description": "PAY-P3-A — race condition 차단 (구멍-A + 구멍-B 동시 검증)",
  "checks": [
    "payment.usecase.ts에 payment.status='refunded' 사전 게이트 박제",
    "payment.usecase.ts에 payment.status='partial_refunded' 사전 게이트 박제",
    "prisma-payment.repository.ts refundPaymentAtomically에 findUniqueOrThrow + updateMany CAS 패턴 박제",
    "payment.usecase.spec.ts에 AC-1 (refunded skip) it 박제",
    "payment.usecase.spec.ts에 AC-2 (partial_refunded skip) it 박제",
    "refund-payment.usecase.spec.ts에 AC-3 (race 동시 환불) it 박제",
    "refund-payment.usecase.spec.ts에 AC-4 (CAS mismatch) it 박제",
    "shared-contracts.md §22 PaymentRaceCondition 신설"
  ]
}
```

**예상 eval 인벤토리 변동**: 65 → **66 regression tasks**

### 5-3. sensor 신설 — `sensor-payment-race-condition.sh`

```bash
#!/bin/bash
# sensor-payment-race-condition.sh
# PAY-P3-A 회귀 차단 — payment.status 사전 게이트 + CAS 패턴 grep

# 1. payment.status='refunded' 사전 게이트
grep -rE "payment\.status\s*===\s*'refunded'" grimoire-server/src/application/payment/ || {
  echo "FAIL: payment.status='refunded' 사전 게이트 박제 0건"
  exit 1
}

# 2. payment.status='partial_refunded' 사전 게이트
grep -rE "payment\.status\s*===\s*'partial_refunded'" grimoire-server/src/application/payment/ || {
  echo "FAIL: payment.status='partial_refunded' 사전 게이트 박제 0건"
  exit 1
}

# 3. findUniqueOrThrow + updateMany CAS 패턴
grep -E "findUniqueOrThrow|updateMany.*credits.*gte" grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts || {
  echo "FAIL: refundPaymentAtomically CAS 패턴 박제 0건"
  exit 1
}

# 4. shared-contracts §22 박제
grep -q "## 22\. PaymentRaceCondition" .claude/shared-contracts.md || {
  echo "FAIL: shared-contracts §22 PaymentRaceCondition 박제 0건"
  exit 1
}

echo "PASS: PAY-P3-A race condition 차단 패턴 정합"
```

**예상 sensor 인벤토리 변동**: 39 → **40 sensors**

### 5-4. shared-contracts §22 신설 (인터페이스 정본)

```markdown
## 22. PaymentRaceCondition (server 도메인 — 결제 race condition 차단)

**위치**:
- UseCase: `grimoire-server/src/application/payment/payment.usecase.ts` (`processNormalizedWebhook` L155-186 + L264 분기)
- UseCase: `grimoire-server/src/application/payment/refund-payment.usecase.ts` (호출자 정합)
- Repository: `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (`refundPaymentAtomically` L129-224)

**적용**: PAYMENT_AUDIT §1 구멍-A (eventId 다른 type 동시 처리 누락) + 구멍-B (transaction race) 동시 차단. DB schema 변경 0건. 외부 인프라 의존 0건.

### 시그니처 — 사전 게이트 (구멍-A 차단)

```typescript
// payment.usecase.ts processNormalizedWebhook 진입 직후
if (payment.status === 'refunded' || payment.status === 'partial_refunded') {
  await this.webhookEventRepo.createIfAbsent({
    eventId: event.eventId,
    source: 'polar',
    eventType: event.type,
    payload: event as unknown as object,
    status: 'skipped',
    errorMessage: `already_${payment.status}`,
  })
  return { processed: false, reason: `already_${payment.status}` }
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
  // CAS 패턴 — race window 차단 (atomic check-and-set)
  const updateResult = await tx.author.updateMany({
    where: {
      id: authorId,
      credits: { gte: actualDeducted },  // 사전 검증된 잔액 정합 — race 시 실패
    },
    data: { credits: { decrement: actualDeducted } },
  })
  if (updateResult.count === 0) {
    throw new Error('CAS_MISMATCH — 다른 트랜잭션이 author.credits를 변경했습니다')
  }
}
```

### 정책

- **사전 게이트 (구멍-A)**: payment.status='refunded' OR 'partial_refunded' → skip (이미 환불 완료된 payment에 대한 재처리 방어)
- **CAS 패턴 (구멍-B)**: `updateMany WHERE credits >= actualDeducted` (Postgres atomic CAS) → 0 row 시 throw 'CAS_MISMATCH' → 호출자 retry 위임 (PAY-P2-2 DLQ)
- **격리 수준**: $transaction은 READ COMMITTED (Postgres 기본). CAS 패턴이 격리 부족분을 보강.
- **재시도 위임**: CAS_MISMATCH throw → payment.usecase catch → webhookEventRepo 'failed' + DLQ enqueue → WebhookRetryJob @Cron 5분 재처리
- **incident-log 박제 의무**: race condition 시도 차단 시 incident-log + logger.warn 동반 (sensor-adversarial-pre-commit P20)
- **DB schema 변경 0건**: advisory_lock + partial unique index는 P2 보류 (replicas ≥2 시점)

### 변경 시 동시 갱신 대상

- `grimoire-server/src/application/payment/payment.usecase.ts` (사전 게이트)
- `grimoire-server/src/application/payment/payment.usecase.spec.ts` (≥ 3 it)
- `grimoire-server/src/application/payment/refund-payment.usecase.ts` (호출자 정합)
- `grimoire-server/src/application/payment/refund-payment.usecase.spec.ts` (≥ 2 it)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (CAS 패턴)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.spec.ts` (≥ 1 it, integration)
- `grimoire-server/docs/api-contract.md` (webhook 처리 상태 표 보강)
- `grimoire-server/docs/data-model.md` (Payment status enum)
- `grimoire-server/SCHEMA.md`
- `grimoire-server/SECURITY.md §3` (결제 원자성 영역)
- `grimoire-server/ADR.md` (결제 race condition 차단 결정)
- `eval/tasks/regression-66-payment-race-condition.json`
- `.claude/scripts/sensor-payment-race-condition.sh`

### 변경 이력

- 2026-05-08 #10_8 PAY-P3-A: 신설 — PAYMENT_AUDIT §1 구멍-A + 구멍-B 동시 차단. payment.status 사전 게이트 (refunded + partial_refunded) + refundPaymentAtomically CAS 패턴 (`findUniqueOrThrow + updateMany WHERE credits >= actualDeducted`). DB schema 변경 0건. PAY-P2-2 DLQ retry 패턴 정합. 정본: `reports/sprint-pay-p3-a-race-condition-progress.md` (Generator 진입 후 박제).
```

**예상 shared-contracts 변동**: §1~21 → **§1~22**

### 5-5. 검증 게이트 종합

| 게이트 | 통과 기준 |
|---|---|
| jest server | 625 → 631+ PASS (회귀 0) |
| eval regression | 65 → 66 PASS (재실행 검증) |
| sensor-payment-race-condition.sh | PASS |
| sensor-adversarial-pre-commit P16 (결제 원자성) | PASS (CAS 패턴 정합) |
| sensor-shared-contracts.sh | PASS (§22 박제 정합) |
| visual-canon-keeper | 면제 (UI 변경 0) |
| cost-accountant | 면제 (외부 API 0) |
| qa Evaluator | CONDITIONAL PASS 또는 PASS (AC 8건 채점) |

---

## §6 멀티에이전트 위임 매트릭스

### 6-1. 본 sprint 위임 순서 (책 Ch 16 Anthropic 3-에이전트 + GMP v2.2 정합)

```
[Step 1] 메인 (orchestration-decision skill) → 본 sprint = server agent 위임 가치 매트릭스 통과 (코드 변경 + spec + sensor + shared-contracts)
[Step 2] grimoire-planner (Initializer, 본 작업) → `.claude/state/sprint-pay-p3-a-race-condition-draft.md` 박제 + AC BDD 8건 박제
[Step 3] cost-accountant 면제 (외부 API 0)
[Step 4] visual-canon-keeper 면제 (UI 변경 0)
[Step 5] grimoire-server (Generator) → 본 sprint 영역:
  - payment.usecase.ts 사전 게이트
  - prisma-payment.repository.ts CAS 패턴
  - 3 spec ≥ 6 it 신설
  - sensor 신설 + eval task 신설 + shared-contracts §22 신설
  - reports/sprint-pay-p3-a-race-condition-progress.md 갱신 (Initializer 산출 영역에서 인계)
  - 핵심 docs 갱신 (api-contract.md / data-model.md / SECURITY.md / ADR.md)
[Step 6] verification-before-completion skill + sensor 회귀 검증
[Step 7] socratic-self-critique skill (14 질문 + Ambiguity ≤ 0.2)
[Step 8] requesting-code-review skill (12 항목 체크리스트)
[Step 9] sensor-adversarial-pre-commit (19 principles, FAIL 0건 강제)
[Step 10] grimoire-qa (Evaluator) → reports/QA_REPORT.md (AC 8건 채점 + jest 631+ + eval 66 + sensor 40 + shared-contracts §22 검증)
[Step 11] commit + push develop (메인 직접, 화이트리스트 hook 통과)
[Step 12] memory 박제 (Stop hook 강제 + incident-log)
```

### 6-2. 위임 매트릭스 (각 agent 책임 영역)

| Agent | 책임 영역 | 산출물 |
|---|---|---|
| **grimoire-planner (Initializer, 본 작업)** | Sprint 계약 13 섹션 + AC BDD 8건 박제 | `.claude/state/sprint-pay-p3-a-race-condition-draft.md` (본 파일) |
| cost-accountant | **면제** (외부 API 0, 마진 영향 0) | 면제 박제 |
| visual-canon-keeper | **면제** (UI 변경 0) | 면제 박제 |
| **grimoire-server (Generator)** | 코드 + spec + sensor + eval + shared-contracts §22 | `reports/sprint-pay-p3-a-race-condition-progress.md` 갱신 + commit |
| **grimoire-qa (Evaluator)** | AC 8건 채점 + jest/eval/sensor 회귀 + 거짓말 차단 (qa 독립 재실행 + 직접 Read) | `reports/QA_REPORT.md` |
| 메인 직접 | commit + push develop (화이트리스트 통과 영역) | 3 레포 develop branch (server + claude-docs) |

### 6-3. infrastructure agent 결합 (HANDOVER §1.6 정합)

- 본 sprint = DB 마이그레이션 0건 → grimoire-infrastructure agent **면제**
- DB schema 변경 시점 (PAY-P3-E FK cascade) = 별도 sprint에서 위임

---

## §7 incident-log 박제 의무 (Mitchell Ghostty 정합)

### 7-1. 본 sprint 진행 중 박제 의무 카테고리

각 카테고리 발견 시 **즉시 박제** (sensor-adversarial-pre-commit P20 + Constitution Principle 20 정합):

| 카테고리 | 박제 시점 | 본 sprint 예상 시나리오 |
|---|---|---|
| **race_condition_blocked** | 사전 게이트 또는 CAS 패턴 차단 시 | AC-1, AC-2, AC-3, AC-4 발동 시점 |
| **race_condition_found** | race 시뮬에서 새 race 발견 시 | AC-7 100 동시 시뮬에서 예상 외 inconsistency |
| **agent_failure** | server agent commit/push 0건인데 자율 시도 | Generator 진입 시 |
| **documentation_gap** | shared-contracts §22 박제 누락 발견 시 | 본 sprint 진행 중 |
| **dev_verification_skip** | code spec PASS만 박제 후 운영 영향 0 보고 | qa Evaluator 채점 시점 |
| **false_report_caught** | 거짓 보고 사슬 발견 시 | 모든 단계 |
| **guard_bypass_attempt** | sensor 우회 시도 시 | sensor-adversarial-pre-commit FAIL |

### 7-2. 박제 명령 표준 (sensor-adversarial-pre-commit 정합)

```bash
bash .claude/scripts/incident-log.sh \
  --category=race_condition_blocked \
  --severity=info \
  --source=payment-usecase \
  --description="PAY-P3-A AC-1 차단 — payment.status=refunded 상태 succeeded webhook 시도"
```

### 7-3. incident-log 검증 게이트

- qa Evaluator는 본 sprint 진행 중 박제된 incident-log를 직접 Read 후 QA_REPORT 박제
- sensor-adversarial-pre-commit은 incident-log 부재 시 FAIL (본 sprint 진행 중 race_condition_blocked 카테고리 ≥ 1건 박제 필수)

---

## §8 dev 작동 검증 영역 (메인 자율 vs 사용자 영역 분리)

### 8-1. 메인 자율 영역 (가드 통과)

| # | 검증 영역 | 명령 | 기대 |
|---|---|---|---|
| 1 | jest server 회귀 | `cd grimoire-server && npm test` | 631+ PASS |
| 2 | eval regression-52~66 | `bash eval/scripts/eval-runner.sh --filter regression-` | 66/66 PASS |
| 3 | sensor-payment-race-condition.sh | `bash .claude/scripts/sensor-payment-race-condition.sh` | PASS |
| 4 | sensor-adversarial-pre-commit P16 | `bash .claude/scripts/sensor-adversarial-pre-commit.sh` | PASS |
| 5 | sensor-shared-contracts.sh | `bash .claude/scripts/sensor-shared-contracts.sh` | PASS (§22 박제 정합) |
| 6 | dev API 회귀 (curl) | `curl -fs https://dev-api.grimoire-book.com/health` | HTTP 200 |
| 7 | dev cron logs 박제 (선택) | `az containerapp logs show ... | grep WebhookRetryJob` | 5분 주기 발동 정상 |

### 8-2. 사용자 명시 권한 영역 (자격증명 영역)

| # | 검증 영역 | 준비 | 명시 키워드 |
|---|---|---|---|
| 1 | POST /payments/webhook valid signature mock + race 시뮬 | Polar dashboard 또는 HMAC 생성 + 동시 2 webhook 송출 | `Polar webhook race 시뮬 진행` |
| 2 | dev 환불 시뮬 + race window 직접 검증 | 테스트 결제 (cancel) + Promise.all curl | `dev 환불 race 시뮬 진행` |
| 3 | dev 24h 안정성 박제 후 prod 영역 | dev 회귀 0건 박제 후 | `prod main 머지 진행` |

### 8-3. 자동 검증 영역 (sensor 영역)

- sensor-payment-race-condition.sh = CI/CD pre-push hook 자동 검증
- eval regression-66 = sensor-eval-trend.sh 자동 검증
- jest server = pre-push hook 자동 검증

---

## §9 사용자 결정 영역 (메인 자율 진행 금지 영역)

### 9-1. main 머지 영역 (.githooks/AGENTS.md §1 정합)

- 본 sprint 진행 중 **develop push만** 자동 (3 레포 server + claude-docs)
- main 머지는 **per-repo 명시 승인** 필수
- 명시 키워드: `server main 머지 진행` / `claude-docs main 머지 진행`

### 9-2. dev curl 자격증명 영역

- POST /payments/webhook valid signature 생성 (Polar HMAC) — 메인 자율 진행 금지
- 사용자 명시: `Polar webhook race 시뮬 진행`

### 9-3. prod 배포 영역

- dev 24h 안정성 박제 후 사용자 명시 필요
- 명시 키워드: `prod 배포 진행` (현재 본 sprint = dev 배포만 자동)

### 9-4. DB schema 변경 영역 (P2 보류)

- advisory_lock 도입 = replicas ≥2 시점 (현재 replicas=1)
- partial unique index 도입 = DB schema 변경 비용 검증 후
- 본 sprint 본질 = DB schema 변경 0건 + CAS 패턴만 적용

---

## §10 Definition of Done (qa Evaluator 채점 기준)

### 10-1. 정량 KPI

- [ ] jest server **631+ PASS** (회귀 0)
- [ ] eval regression **66 PASS** (재실행 검증)
- [ ] sensor **40 PASS** (sensor-payment-race-condition.sh 신설)
- [ ] shared-contracts **§22 박제** (PaymentRaceCondition)
- [ ] AC BDD **8건 PASS** (qa 독립 재실행 + 직접 Read 검증)
- [ ] incident-log **≥ 1건 박제** (race_condition_blocked 카테고리)

### 10-2. 정성 검증

- [ ] payment.usecase.ts payment.status='refunded' OR 'partial_refunded' 사전 게이트 박제
- [ ] prisma-payment.repository.ts CAS 패턴 박제 (`findUniqueOrThrow + updateMany WHERE credits >= actualDeducted`)
- [ ] CAS_MISMATCH throw + 호출자 retry 위임 정합
- [ ] PAY-P2-2 DLQ 패턴 정합 (CAS_MISMATCH → webhookEventRepo 'failed' + DLQ enqueue)
- [ ] sensor-adversarial-pre-commit P16 (결제 원자성) PASS

### 10-3. 산출물 박제

- [ ] **Draft commit** + push develop (`.claude/state/sprint-pay-p3-a-race-condition-draft.md` 박제)
- [ ] Generator (server agent) 진입 후 `reports/sprint-pay-p3-a-race-condition-progress.md` 신설 + 갱신
- [ ] qa Evaluator의 `reports/QA_REPORT.md` CONDITIONAL PASS 또는 PASS

### 10-4. 회귀 차단

- [ ] PAY-P0-1 (webhook event_id 멱등성) 회귀 0
- [ ] PAY-P0-2 (PG↔DB 정합성 cron) 회귀 0
- [ ] PAY-P0-3 (운영자 수동 크레딧 UI) 회귀 0
- [ ] PAY-P1-1 (Refund 4분기 처리) 회귀 0
- [ ] PAY-P1-3 (결제 실패 retry + cleanup cron) 회귀 0
- [ ] PAY-P2-1 (부분 환불 비율) 회귀 0
- [ ] PAY-P2-2 (Webhook DLQ + retry) 회귀 0
- [ ] PAY-P2-3 (SmsServicePort 캡슐화) 회귀 0
- [ ] PAY-P2-4 (AdminAuditLog beforeState/afterState) 회귀 0

---

## §11 회귀 차단 영역 (eval regression-52~65 회귀 0 보장)

### 11-1. 결제 회귀 매트릭스

| eval task | sprint | 본 sprint 영향 | 회귀 검증 |
|---|---|---|---|
| regression-52 | PAY-P0-1 webhook event_id 멱등성 | webhook_events @unique 회귀 0 | 자동 |
| regression-53 | PAY-P0-2 PG↔DB 정합성 cron | reconciliation cron 회귀 0 | 자동 |
| regression-54 | PAY-P0-3 admin grant credits | admin UI 회귀 0 | 자동 |
| regression-55 | PAY-P1-1 refund atomicity | refundPaymentAtomically CAS 패턴 적용 — **회귀 0 + 강화** | 자동 + 추가 it |
| regression-56 | (예약) | — | — |
| regression-57 | PAY-P1-3 payment retry reuse | findReusablePendingPayment 회귀 0 | 자동 |
| regression-58 | PAY-P2-1 부분 환불 비율 | partial_refunded 사전 게이트 추가 — **회귀 0 + 강화** | 자동 + 추가 it |
| regression-59~65 | PAY-P2-2/3/4 + 기타 | webhook-retry/SMS/audit 회귀 0 | 자동 |
| regression-66 | **PAY-P3-A 본 sprint** | 신설 | 신설 |

### 11-2. 강화 영역 (회귀 0 + 보강)

- **regression-55 (PAY-P1-1)**: refundPaymentAtomically CAS 패턴 적용 → 기존 시나리오 회귀 0 + 동시 환불 race 차단 추가 (AC-3 + AC-4)
- **regression-58 (PAY-P2-1)**: partial_refunded 사전 게이트 추가 → 기존 부분 환불 시나리오 회귀 0 + 추가 부분 환불 webhook skip 추가 (AC-2)

---

## §12 변경 이력

- **2026-05-08 #10_8 본 세션** — 본 Sprint 계약 신설 (`.claude/state/` Draft 박제 영역, PP-13 화이트리스트 우회). 입력 자료 5건 (sprint-pay-p3-master-plan-draft.md + PAYMENT_AUDIT-2026-05-07.md + PAYMENT_SYSTEM_PLAN.md + grimoire-server payment 디렉토리 직접 Read + shared-contracts §13 + §14) 직접 Read 후:
  - **§0 한 줄 요약** + **§1 배경** (구멍-A/B raw 인용 + 메인 정밀 검증) + **§2 목표** (KPI 5건 + 비목표 7건) + **§3 변경 영역** (server 핵심 코드 5건 + 신설 6건 + 회귀 차단 4건) + **§4 AC BDD 8건** (qa Evaluator 채점 정본 형식) + **§5 검증 매트릭스** (jest ≥6 it / eval task 1건 / sensor 1건 / shared-contracts §22) + **§6 멀티에이전트 위임** (책 Ch 16 정합) + **§7 incident-log 박제 의무** (Mitchell Ghostty 정합) + **§8 dev 검증 영역** (메인 자율 + 사용자 영역 분리) + **§9 사용자 결정 영역** (main 머지 + dev curl + prod 배포 + DB schema P2) + **§10 Definition of Done** (정량 + 정성 + 산출물 + 회귀) + **§11 회귀 차단 영역** (eval 52~65 회귀 0) + **§12 변경 이력** 박제.
  - **메인 정밀 발견 (직접 Read)**: 구멍-A 본질 = `payment.status='refunded' OR partial_refunded` 사전 게이트 부재 (기존 `payment.status='completed'` 약식 게이트는 L175-186 박제, 환불 후 재진입 차단은 추가 필요). 구멍-B 본질 = `tx.author.findUnique → update decrement` READ COMMITTED race window (CAS 패턴 권장 = `findUniqueOrThrow + updateMany WHERE credits >= actualDeducted` Postgres atomic CAS).

---

## 참조 (file:line)

### 정본 문서

- `.claude/state/sprint-pay-p3-master-plan-draft.md` — PAY-P3 마스터 플랜 (본 sprint 위치 박제)
- `research/PAYMENT_AUDIT-2026-05-07.md §1` — 구멍-A/B raw
- `research/PAYMENT_SYSTEM_PLAN.md` — DB 모델 + transaction 정책
- `.claude/shared-contracts.md §13` — RefundPaymentAtomically (race condition 영역 인접)
- `.claude/shared-contracts.md §14` — PaymentRetryReuse (race condition 영역 인접)
- `.claude/shared-contracts.md §22` (예정) — PaymentRaceCondition 신설 정본 (본 sprint 산출)

### 핵심 코드 (server, 직접 Read 검증)

- `application/payment/payment.usecase.ts:147-160` `processNormalizedWebhook` 진입 (eventId 멱등성 L1) — **본 sprint 보강 영역**
- `application/payment/payment.usecase.ts:175-186` `payment.status='completed'` 약식 게이트 — **본 sprint 사전 게이트 추가 위치**
- `application/payment/payment.usecase.ts:264-301` `event.status='cancel'` 분기 (refund usecase 호출) — **본 sprint 호출자 정합**
- `application/payment/refund-payment.usecase.ts:99-115` refundPaymentAtomically 호출자 — **본 sprint 호출자 정합**
- `adapter/outbound/persistence/prisma-payment.repository.ts:144-224` `refundPaymentAtomically` $transaction — **본 sprint CAS 패턴 적용 영역**
- `adapter/outbound/persistence/prisma-payment.repository.ts:179-198` `tx.author.findUnique → update decrement` — **본 sprint 핵심 변경 영역 (구멍-B)**
- `adapter/outbound/persistence/prisma-payment.repository.ts:25-39` `completePaymentAtomically` — **본 sprint 보강 영역 (선택, AC-7 영향)**
- `domain/port/outbound/payment-repository.port.ts:90-102` refundPaymentAtomically 시그니처 — **본 sprint 시그니처 변경 0건 (내부 구현만 변경)**
- `application/payment/webhook-retry.job.ts:55-124` WebhookRetryJob @Cron 5분 — **본 sprint CAS_MISMATCH retry 위임 영역**

### Sprint progress 박제 영역 (본 sprint 신설 후 영역)

- `reports/sprint-pay-p3-a-race-condition-progress.md` (Generator 진입 후 신설)

### 관련 sprint progress (완료)

- `reports/sprint-pay-p0-1/2/3-progress.md`
- `reports/sprint-pay-p1-1-refund-progress.md`
- `reports/sprint-pay-p1-3-retry-policy-progress.md`
- `reports/sprint-pay-p2-1/2/3/4-*.md`

### 관련 정본 문서 (Generator가 갱신할 영역)

- `grimoire-server/docs/api-contract.md` — webhook 처리 상태 표
- `grimoire-server/docs/data-model.md` — Payment status enum
- `grimoire-server/SCHEMA.md` — Payment status 7가지
- `grimoire-server/SECURITY.md §3` — 결제 원자성
- `grimoire-server/ADR.md` — 결제 race condition 차단 결정
- `grimoire-server/CLAUDE.md §9` — 결제/크레딧 원자성 절대 규칙 (정합 검증)

---

**상태**: Sprint 계약 13 섹션 + AC BDD 8건 박제 완료 (`.claude/state/` Draft 영역, PP-13 화이트리스트 통과). **다음 단계 = grimoire-server agent (Generator) 위임 진입**. 본 Draft가 server agent 진입 정본 — 모호 영역 0건. shared-contracts §22 PaymentRaceCondition 신설 영역 박제. 사용자 명시 후 즉시 server agent (Generator) 위임 → qa Evaluator 위임 → 메인 commit/push 진행.
