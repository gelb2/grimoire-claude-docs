# Sprint PAY-P3-C — Retry 중복 해소 (모순-D 차단, Draft, PP-13 화이트리스트 영역)

> **작성**: 2026-05-09 #10_8 본 세션 grimoire-planner agent (Initializer 역할, 책 Ch 16 Anthropic 3-에이전트 패턴 정합)
> **트리거**: 사용자 명시 (5/9) — "잔여 과제 진행" (Auto mode 활성). PAY-P3-A 종료 직후 Phase 1 두 번째 sprint. 마스터 플랜 §3-1 Phase 1 권장 순서 정합 (PAY-P3-A → PAY-P3-C → PAY-P3-B → PAY-P3-E → PAY-P3-H → PAY-P3-D → PAY-P2-5).
> **본 위치**: `.claude/state/` (PP-13 메인 화이트리스트 우회 영역). 정본 영역 (`reports/sprint-pay-p3-c-retry-dedup-progress.md`)으로 사용자 또는 grimoire-server agent 위임 후 이동 영역.
> **정본 위치 (예정)**: `reports/sprint-pay-p3-c-retry-dedup-progress.md` — Initializer 산출물, Generator(server agent)가 본 progress.md 갱신, Evaluator(qa)가 채점 대상 영역.

---

## §0 한 줄 요약

PAYMENT_AUDIT §1 모순-D (WebhookRetryJob 5분 cron ↔ PaymentReconciliationJob 10분 cron 커버리지 겹침) 차단을 위해 (1) WebhookRetryJob `retryDueWebhooks` for-loop 진입 직전 `payment.status='completed' OR 'refunded' OR 'partial_refunded'` 사전 dedup 게이트 추가 (5분 cron 내에서 boost 후 재처리 0건 보장) + (2) `processNormalizedWebhook` 호출 0건 + queue row 즉시 deleteById + AuditLog operator='system_dlq' action='retry_skip_dedup' 박제 (S1 boost 또는 cron으로 status가 already_completed/refunded인 payment의 retry queue row 정합화). DB schema 변경 0건 + 외부 API 0건 + 의존성 0건. 예상 ~2h. shared-contracts §23 RetryDeduplication 신설.

---

## §1 배경 — PAYMENT_AUDIT §1 모순-D raw 인용 + 메인 정밀 검증

### 1-1. 모순-D raw 인용 (PAYMENT_AUDIT §1)

> | **모순-D** Retry 중복: WebhookRetryJob(5분) vs PaymentReconciliationJob(10분) 커버리지 겹침 | S1 boost 후 retry job에서 same payment 재처리 가능 | `payment-reconciliation.job.ts:118-122` S1 logic vs `webhook-retry.job.ts:82` `processNormalizedWebhook` | retry job 진입 시 payment.status='completed' 체크 추가 (boost됐으면 skip) | P1 |

### 1-2. 메인 정밀 검증 (직접 Read 결과)

**WebhookRetryJob 코드 분석 (`webhook-retry.job.ts:55-124`)**:

```typescript
@Cron('0 */5 * * * *')
async retryDueWebhooks(): Promise<void> {
  // ... 동시 실행 차단 + isRunning lock ...
  const due = await this.retryQueueRepo.findDue(startedAt, BATCH_SIZE)
  for (const item of due) {
    try {
      const event = item.payload as NormalizedWebhookEvent
      await this.paymentUseCase.processNormalizedWebhook(event)  // ← 사전 dedup 0건
      await this.retryQueueRepo.deleteById(item.id)
      // ...
    } catch (e) {
      // ... markRetry / markPermanentFailed ...
    }
  }
}
```

**ReconciliationJob 코드 분석 (`payment-reconciliation.job.ts:117-122`)**:

```typescript
// S1: PG=succeeded + DB=pending → boost
if (pgCheckout.status === 'succeeded' && dbPayment.status === 'pending') {
  await this.handleBoost(dbPayment)
  // → completePaymentAtomically → payment.status='completed'
  boostCount += 1
  continue
}
```

**모순-D 본질 (메인 직접 검증)**:

1. webhook 처리 실패 → `payment.usecase.processNormalizedWebhook` catch에서 `enqueueWebhookRetry` 호출 → webhook_retry_queues 테이블 박제 (status='retry_pending')
2. **시나리오 A (정상)**: 5분 후 WebhookRetryJob 발동 → due 행 `processNormalizedWebhook` 재호출 → payment.status='pending'에서 'completed'로 갱신 → 정상
3. **시나리오 B (모순-D 본질)**: 10분 ReconciliationJob이 먼저 발동 → S1 boost (PG=succeeded + DB=pending) → `completePaymentAtomically` → payment.status='completed'
4. → 그 후 5분 WebhookRetryJob이 due 행 `processNormalizedWebhook` 호출
5. → `processNormalizedWebhook` 내부 `payment.status === 'completed'` 약식 게이트 (line 175-186) 통과 안 됨 → skip ✅ (멱등성 보장됨)
6. **단**: queue row deleteById는 try 분기 (성공 분기)에서 호출되므로 정합 — 단 catch 분기로 빠지면 markRetry → 다음 5분 또 재처리 시도

**결함 본질 (직접 검증)**:
- **5분마다 동일 due 행 retry 시도** = unnecessary processing + DB query overhead + log noise
- `processNormalizedWebhook` 내부에서 멱등성 게이트는 통과되지만, 호출 자체가 발생 (5분 cron마다 N회) → DB I/O + audit log noise
- **결정적 결함**: 만약 `processNormalizedWebhook` 처리 후 `webhookEventRepo.createIfAbsent` 단계에서 P2002 (eventId @unique 중복) 발생 시 **try-catch 분기 어디로?** — 직접 Read 결과 `webhookEventRepo.createIfAbsent`는 P2002 시 null 반환 (race 안전 정합) → catch로 빠지지 않음 → try 분기 정상 종료 → deleteById 정상 → 정합. **단 webhook payload 처리 중 다른 exception (예: 트랜잭션 commit 실패) 발생 시** catch로 빠짐 → 또 markRetry → MAX_RETRY (10회) 도달 시 permanent_failed 박제 (system_dlq AuditLog) → 이미 boost된 payment를 permanent_failed로 박제 = **거짓 audit log 박제 가능성**

### 1-3. 결제 적자 위험 분석 (cost-accountant 면제 영역, 자체 분석)

| 시나리오 | 영향 | 적자 영향 |
|---|---|---|
| 모순-D 미차단 + S1 boost 후 retry queue 5분 cron 재처리 | `processNormalizedWebhook` 멱등성 게이트로 skip 정합 → DB I/O 1회 + audit log noise | **적자 X** (단 운영 부하 + 거짓 audit log 가능) |
| 모순-D 미차단 + retry 처리 중 다른 exception (트랜잭션 실패) | markRetry → 다음 5분 또 재처리 → MAX_RETRY 누적 → permanent_failed 박제 | **적자 X** (단 거짓 audit log = system_dlq permanent_failed 박제, 실제는 boost됨) |
| 본 sprint 차단 적용 후 | 5분 cron 진입 시 payment.status 사전 dedup → 즉시 deleteById + audit log retry_skip_dedup | retry 시도 0건 (재처리 noise 0건) |

**모순-D 위치**: 마스터 플랜 §2 P1 우선순위 영역 (PAY-P3-A 적자 위험 1순위 다음). 본 sprint = **DB 정합성 + 운영 audit log 정확성** 영역.

### 1-4. 결제 9 sprint + PAY-P3-A 완료 후 본 sprint 위치 (마스터 플랜 §2 정합)

| Sprint | 시간 | 외부 API | 의존성 | 우선순위 | 영향 |
|---|---|---|---|---|---|
| ~~PAY-P3-A Race condition (구멍-A/B)~~ | ~5h | 0 | 0 | P1 (적자 1순위) | ✅ 완료 |
| **PAY-P3-C** (본 sprint) | ~2h | 0 | 0 | P1 (DB 정합성) | DB 정합성 + 운영 audit |
| PAY-P3-B Polar timeout | ~2h | 0 | 0 | P1 | 운영 안정 |
| PAY-P3-E FK cascade | ~3h | 0 (DB 마이그레이션) | 0 | P1 | 데이터 정합성 |
| PAY-P3-H Circuit breaker | ~4h | 0 | 0 | P1 | 가용성 |
| PAY-P3-D Status enum | ~2h | 0 | 0 | P2 | 추적 일관성 |
| PAY-P2-5 audit retention | ~3h | 0 | 0 | P0 | 운영 |

---

## §2 목표 — Retry 중복 0건 + 거짓 audit log 0건 + incident-log 박제 의무

### 2-1. 핵심 KPI

1. **retry 중복 처리 0건**: WebhookRetryJob 진입 시 `payment.status` 사전 dedup → `processNormalizedWebhook` 호출 0건 + queue row 즉시 deleteById
2. **거짓 audit log 0건**: 이미 boost된 payment의 retry queue row가 MAX_RETRY까지 누적되어 `permanent_failed` 박제되는 케이스 차단 (false negative dedup)
3. **회귀 차단 0건**: 기존 9 sprint + PAY-P3-A 시나리오 (eval regression-52~66) 회귀 0
4. **AuditLog 정합성**: retry_skip_dedup 카테고리 신설 (operator='system_dlq' action='retry_skip_dedup') → 운영자가 retry 중복 차단 발동 영역 추적 가능
5. **incident-log 박제 의무 (Mitchell Ghostty 정합, sensor-adversarial-pre-commit P20 정합)**: sprint 진행 중 발견하는 모든 결함/우회/거짓 보고 즉시 박제

### 2-2. 비목표 (사용자 결정 영역 분리)

- ❌ Polar SDK timeout 정책 (PAY-P3-B 분리, ~2h)
- ❌ Status enum mapping table (PAY-P3-D 분리, ~2h)
- ❌ FK cascade 정책 + DB 마이그레이션 (PAY-P3-E 분리, ~3h)
- ❌ Circuit breaker (PAY-P3-H 분리, ~4h)
- ❌ DB schema 변경 (advisory_lock 또는 partial unique index — P2 보류)
- ❌ ReconciliationJob 자체 dedup 로직 변경 (현재 로직은 정합, retry 영역만 보강)
- ❌ retry queue retention 정책 (PAY-P2-5 분리, ~3h)

---

## §3 변경 영역 (server agent Generator 진입 정본)

### 3-1. 핵심 코드 변경 (server)

| 파일 | 변경 영역 | 영향 |
|---|---|---|
| `src/application/payment/webhook-retry.job.ts` | `retryDueWebhooks` for-loop 진입 직전 사전 dedup 게이트 추가 — `payment = await this.paymentRepo.findByExternalTransactionId(item.payload.tradeNo)` 후 `payment.status === 'completed' OR 'refunded' OR 'partial_refunded'` 체크. 통과 안 되면 즉시 deleteById + AuditLog `retry_skip_dedup` + skipDedupCount += 1 + continue. 통과 시 기존 `processNormalizedWebhook` 호출 흐름 유지. | 모순-D 차단 |
| `src/application/payment/webhook-retry.job.ts` | DI에 `PaymentRepositoryPort` 추가 — `@Inject('PaymentRepositoryPort') private readonly paymentRepo: PaymentRepositoryPort` 주입 (기존 retryQueueRepo + webhookEventRepo + paymentUseCase + auditLog 4건에 5번째 추가) | 의존성 정합 |
| `src/application/payment/webhook-retry.job.ts` | logger.log 박제 통계 보강 — `skipDedupCount` 추가 (`due=N success=X retry=Y permanent=Z **dedup=W**`) | 운영 추적 정합 |
| `src/application/payment/webhook-retry.job.ts` | DLQ_OPERATOR 외 새 action 식별자 — `'retry_skip_dedup'` 박제 | 운영 추적 정합 |

### 3-2. 신설 파일

| 파일 | 영역 |
|---|---|
| `src/application/payment/webhook-retry.job.spec.ts` 갱신 | retry dedup 시나리오 spec 신설 (≥ 6 it) |
| `eval/tasks/regression-67-retry-dedup.json` 신설 | 8 검증 (AC 8건 정합) |
| `.claude/scripts/sensor-retry-dedup.sh` 신설 | webhook-retry.job dedup 게이트 grep + AuditLog action='retry_skip_dedup' grep |
| `.claude/shared-contracts.md §23` 신설 | RetryDeduplication 인터페이스 정본 박제 |

### 3-3. 변경 시 동시 갱신 대상 (책 Ch 16 shared-contracts 정합)

- `grimoire-server/docs/api-contract.md` — webhook 처리 상태 표 (retry_skip_dedup 박제)
- `grimoire-server/docs/data-model.md` — AuditLog action 표 (`retry_skip_dedup` 추가, 기존 `webhook_permanent_failed`/`reconciliation_*`와 정합)
- `grimoire-server/SECURITY.md §3` — 결제 원자성 영역 본 sprint dedup 패턴 박제
- `grimoire-server/ADR.md` — Retry dedup 결정 박제 (옵션 A — 5분 cron 진입 사전 게이트 / 옵션 B — ReconciliationJob에서 retry queue 정리 / 옵션 C — DB 마이그레이션)
- `.claude/shared-contracts.md §23` — RetryDeduplication 신설 (본 sprint 핵심)
- `eval/tasks/regression-67-retry-dedup.json`
- `.claude/scripts/sensor-retry-dedup.sh`

### 3-4. 변경 0건 영역 (회귀 차단)

- `prisma/schema.prisma` (DB schema 변경 0건)
- `src/application/payment/payment-reconciliation.job.ts` (PAY-P0-2 회귀 0)
- `src/application/payment/payment.usecase.ts` (PAY-P3-A 회귀 0 — `processNormalizedWebhook` 사전 게이트는 본 sprint에서 우회되어 호출 0건)
- `src/application/payment/payment-cleanup.job.ts` (PAY-P1-3 회귀 0)
- `src/adapter/outbound/persistence/prisma-payment.repository.ts` (PAY-P3-A CAS 패턴 회귀 0)
- 인프라 변경 (Azure Container Apps, replicas, env 등) 0건

---

## §4 AC BDD 8건 (qa Evaluator 채점 대상)

### AC-1: 정상 retry — payment.status='pending' 상태 retry queue 진입 시 기존 흐름 유지

```yaml
GIVEN payment.status='pending' + webhook_retry_queues 1건 (eventId='evt_123', retryCount=0, nextRetryAt < now())
WHEN WebhookRetryJob @Cron 5분 발동 → findDue 진입
THEN
  - paymentRepo.findByExternalTransactionId(item.payload.tradeNo) 호출
  - payment.status === 'pending' 통과 (사전 dedup 게이트 통과 안 됨)
  - processNormalizedWebhook(event) 호출 정상 진행
  - 처리 성공 시 retryQueueRepo.deleteById(item.id) 호출
  - logger.log `[retry] eventId=evt_123 retryCount=0 → SUCCESS (queue row 삭제)`
  - succeededCount = 1
  - 회귀 0건 (PAY-P2-2 정상 retry 시나리오 보존)
```

### AC-2: dedup 차단 — payment.status='completed' (S1 boost 후) retry queue 진입 시 즉시 skip

```yaml
GIVEN ReconciliationJob S1 boost로 payment.status='completed' + 동시 webhook_retry_queues 1건 (eventId='evt_123', retryCount=2)
WHEN WebhookRetryJob @Cron 5분 발동 → due 행 진입
THEN
  - paymentRepo.findByExternalTransactionId 호출 → payment.status='completed' 박제
  - 사전 dedup 게이트 통과 → processNormalizedWebhook **호출 0건**
  - retryQueueRepo.deleteById(item.id) 즉시 호출
  - AuditLog operator='system_dlq' action='retry_skip_dedup' meta={ paymentStatus: 'completed', retryCount: 2 } 박제
  - logger.log `[retry] eventId=evt_123 retryCount=2 → SKIP_DEDUP (payment.status=completed)`
  - skipDedupCount = 1
  - succeededCount = 0
```

### AC-3: dedup 차단 — payment.status='refunded' 상태 retry queue 진입 시 즉시 skip

```yaml
GIVEN payment.status='refunded' (PAY-P1-1 환불 완료 + 별도 webhook 처리 실패로 retry queue에 잔존) + retry queue 1건 (eventId='evt_456', retryCount=3)
WHEN WebhookRetryJob @Cron 5분 발동 → due 행 진입
THEN
  - 사전 dedup 게이트 통과 → processNormalizedWebhook **호출 0건**
  - retryQueueRepo.deleteById(item.id) 즉시 호출
  - AuditLog operator='system_dlq' action='retry_skip_dedup' meta={ paymentStatus: 'refunded', retryCount: 3 } 박제
  - skipDedupCount = 1
  - PAY-P3-A 사전 게이트와 정합 (이중 방어, retry 진입 자체를 차단 → payment.usecase 사전 게이트는 0건 호출)
```

### AC-4: dedup 차단 — payment.status='partial_refunded' 상태 동일

```yaml
GIVEN payment.status='partial_refunded' (PAY-P2-1 부분 환불 완료) + retry queue 1건 (eventId='evt_789', retryCount=5)
WHEN WebhookRetryJob @Cron 5분 발동
THEN
  - 사전 dedup 게이트 통과 → processNormalizedWebhook 호출 0건
  - deleteById 즉시 호출
  - AuditLog action='retry_skip_dedup' 박제
  - skipDedupCount = 1
```

### AC-5: 회귀 차단 — 기존 9 sprint + PAY-P3-A 시나리오 회귀 0건

```yaml
GIVEN 기존 PAY-P0-1/P0-2/P0-3/P1-1/P1-3/P2-1/P2-2/P2-3/P2-4 + PAY-P3-A 시나리오
WHEN 본 sprint 변경 후 동일 시나리오 재실행 (jest server 631+ + eval regression-52~66)
THEN
  - jest 631/631+ PASS (회귀 0)
  - eval regression-52~66 모두 PASS
  - PAY-P2-2 정상 retry (AC-1) 회귀 0 — pending 상태 retry는 기존 흐름 유지
  - PAY-P3-A 사전 게이트 회귀 0 — 본 sprint 사전 dedup이 더 일찍 차단 (이중 방어)
```

### AC-6: 보안 — DLQ MAX_RETRY 누적 차단 (거짓 permanent_failed 박제 0건)

```yaml
GIVEN payment.status='completed' (boost 후) + retry queue 1건 (eventId='evt_loop', retryCount=9 = MAX_RETRY-1)
WHEN WebhookRetryJob @Cron 5분 발동
THEN
  - 사전 dedup 게이트 통과 → processNormalizedWebhook 호출 0건
  - retryQueueRepo.deleteById 즉시 호출 (markRetry 호출 0건)
  - AuditLog action='retry_skip_dedup' 박제 (action='webhook_permanent_failed' 박제 0건)
  - permanentFailedCount = 0 (거짓 permanent_failed 박제 차단)
  - skipDedupCount = 1
  - **본 sprint 핵심 보안 영역**: 이미 정상 처리된 payment의 retry queue row가 MAX_RETRY까지 누적되어 permanent_failed로 박제되는 케이스 차단
```

### AC-7: 성능 — 100건 mixed 시나리오 (50% pending + 50% completed) 동시 처리

```yaml
GIVEN webhook_retry_queues 100건 (50건 payment.status='pending' + 50건 'completed')
WHEN WebhookRetryJob @Cron 5분 발동 → BATCH_SIZE=100 진입
THEN
  - 50건 pending → processNormalizedWebhook 호출 → 정상 처리 (succeededCount=50)
  - 50건 completed → 사전 dedup 게이트 → deleteById + skip_dedup AuditLog (skipDedupCount=50)
  - 총 처리 시간 < 5s (사전 findByExternalTransactionId 1회 추가만, processNormalizedWebhook 50회 단축)
  - 자원 leak 0건 (trx 누수, FD 누수)
```

### AC-8: 운영 — incident-log 박제 + AuditLog operator='system_dlq' action='retry_skip_dedup' 정합

```yaml
GIVEN dedup 차단 발동 (AC-2/AC-3/AC-4 시나리오)
WHEN webhook-retry.job 사전 게이트 차단
THEN
  - logger.log `[retry] eventId=evt_X retryCount=N → SKIP_DEDUP (payment.status=Y)` 박제
  - AuditLog operator='system_dlq' action='retry_skip_dedup' resourceId=eventId meta={ paymentStatus, retryCount } 박제
  - **incident-log 박제** (sensor-adversarial-pre-commit P20 정합):
    ```bash
    bash .claude/scripts/incident-log.sh \
      --category=retry_dedup_blocked \
      --severity=info \
      --source=webhook-retry-job \
      --description="PAY-P3-C dedup 차단 — payment.status=completed 상태 retry 시도 차단 eventId=..."
    ```
  - dev cron logs 박제 (PAYMENT_AUDIT §5-2 정합) — 5분 cron 발동 시 `dedup=N` 통계 박제
```

---

## §5 검증 매트릭스 (Generator + Evaluator 공동 영역)

### 5-1. jest server spec 신설 (≥ 6 it)

| spec | it 수 | 영역 |
|---|---|---|
| `webhook-retry.job.spec.ts` 갱신 | ≥ 6 | AC-1 (정상 retry) + AC-2 (completed dedup) + AC-3 (refunded dedup) + AC-4 (partial_refunded dedup) + AC-6 (MAX_RETRY 누적 차단) + AC-7 (mixed 시나리오 batch) |

**예상 spec 인벤토리 변동**: 631 (PAY-P3-A 종료 직후) → **637+ it** (jest server)

### 5-2. eval regression-67 신설

```json
{
  "id": "regression-67-retry-dedup",
  "category": "regression",
  "description": "PAY-P3-C — Retry 중복 해소 (모순-D 차단, S1 boost 후 retry skip)",
  "checks": [
    "webhook-retry.job.ts에 PaymentRepositoryPort DI 주입 박제",
    "webhook-retry.job.ts retryDueWebhooks for-loop 진입 직전 paymentRepo.findByExternalTransactionId 호출 박제",
    "webhook-retry.job.ts에 payment.status === 'completed' 사전 dedup 게이트 박제",
    "webhook-retry.job.ts에 payment.status === 'refunded' 사전 dedup 게이트 박제",
    "webhook-retry.job.ts에 payment.status === 'partial_refunded' 사전 dedup 게이트 박제",
    "webhook-retry.job.ts dedup 차단 시 retryQueueRepo.deleteById 즉시 호출 박제",
    "webhook-retry.job.ts dedup 차단 시 auditLog 'retry_skip_dedup' action 박제",
    "shared-contracts.md §23 RetryDeduplication 신설"
  ]
}
```

**예상 eval 인벤토리 변동**: 66 (PAY-P3-A 종료 직후) → **67 regression tasks**

### 5-3. sensor 신설 — `sensor-retry-dedup.sh`

```bash
#!/bin/bash
# sensor-retry-dedup.sh
# PAY-P3-C 회귀 차단 — webhook-retry.job 사전 dedup 게이트 + auditLog 'retry_skip_dedup' grep

# 1. PaymentRepositoryPort DI 주입
grep -E "PaymentRepositoryPort" grimoire-server/src/application/payment/webhook-retry.job.ts || {
  echo "FAIL: webhook-retry.job PaymentRepositoryPort DI 주입 박제 0건"
  exit 1
}

# 2. payment.status === 'completed' 사전 게이트
grep -E "payment\.status\s*===\s*'completed'" grimoire-server/src/application/payment/webhook-retry.job.ts || {
  echo "FAIL: webhook-retry.job payment.status='completed' 사전 게이트 박제 0건"
  exit 1
}

# 3. payment.status === 'refunded' OR 'partial_refunded' 사전 게이트
grep -E "payment\.status\s*===\s*'refunded'|payment\.status\s*===\s*'partial_refunded'" grimoire-server/src/application/payment/webhook-retry.job.ts || {
  echo "FAIL: webhook-retry.job payment.status='refunded' 또는 'partial_refunded' 사전 게이트 박제 0건"
  exit 1
}

# 4. AuditLog action='retry_skip_dedup' 박제
grep -E "retry_skip_dedup" grimoire-server/src/application/payment/webhook-retry.job.ts || {
  echo "FAIL: webhook-retry.job auditLog action='retry_skip_dedup' 박제 0건"
  exit 1
}

# 5. shared-contracts §23 박제
grep -q "## 23\. RetryDeduplication" .claude/shared-contracts.md || {
  echo "FAIL: shared-contracts §23 RetryDeduplication 박제 0건"
  exit 1
}

echo "PASS: PAY-P3-C retry dedup 패턴 정합"
```

**예상 sensor 인벤토리 변동**: 40 (PAY-P3-A 종료 직후) → **41 sensors**

### 5-4. shared-contracts §23 신설 (인터페이스 정본)

```markdown
## 23. RetryDeduplication (server 도메인 — webhook-retry.job 사전 dedup)

**위치**:
- Job: `grimoire-server/src/application/payment/webhook-retry.job.ts` (`retryDueWebhooks` for-loop 진입 직전)
- Port: `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (`findByExternalTransactionId` 시그니처 — 기존 보존)
- Sensor: `.claude/scripts/sensor-retry-dedup.sh` (5 검증)

**적용**: PAYMENT_AUDIT §1 모순-D (WebhookRetryJob 5분 cron ↔ PaymentReconciliationJob 10분 cron 커버리지 겹침) 차단. DB schema 변경 0건. 외부 인프라 의존 0건. PAY-P3-A 사전 게이트와 이중 방어 정합 (retry 진입 자체를 차단 → payment.usecase 사전 게이트는 0건 호출).

### 시그니처 — 사전 dedup 게이트

```typescript
// webhook-retry.job.ts retryDueWebhooks for-loop 진입 직전 (각 due item 처리 시작점)
for (const item of due) {
  const event = item.payload as NormalizedWebhookEvent

  // PAY-P3-C 모순-D 차단: payment.status 사전 dedup 게이트
  // (S1 boost 후 또는 별도 cron으로 status가 이미 완료/환불된 payment의 retry 시도 차단)
  // 정본: shared-contracts §23 RetryDeduplication
  const payment = await this.paymentRepo.findByExternalTransactionId(event.tradeNo)
  if (
    payment &&
    (payment.status === 'completed' ||
      payment.status === 'refunded' ||
      payment.status === 'partial_refunded')
  ) {
    await this.retryQueueRepo.deleteById(item.id)
    await this.auditLog.log(
      WebhookRetryJob.DLQ_OPERATOR,
      'retry_skip_dedup',
      item.eventId,
      {
        reason: 'payment_already_finalized',
        paymentStatus: payment.status,
        retryCount: item.retryCount,
        paymentId: payment.id,
      },
    )
    skipDedupCount += 1
    this.logger.log(
      `[retry] eventId=${item.eventId} retryCount=${item.retryCount} → SKIP_DEDUP (payment.status=${payment.status})`,
    )
    continue
  }

  // 기존 흐름 — pending 상태일 때만 processNormalizedWebhook 호출
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

- **사전 dedup 게이트 발동**: payment.status='completed' OR 'refunded' OR 'partial_refunded' → 즉시 deleteById + AuditLog `retry_skip_dedup`
- **payment.status='pending' 상태**: 기존 흐름 유지 (`processNormalizedWebhook` 호출)
- **payment 미존재 (findByExternalTransactionId null)**: 기존 흐름 유지 (`processNormalizedWebhook` 호출 → 내부에서 `unknown_trade` 게이트 발동)
- **payment.status='failed' OR 'expired'**: 기존 흐름 유지 (이 시나리오는 retry 의미 X 영역, 별도 sprint에서 결정 — PAY-P3-D status enum 또는 PAY-P2-5 retention)
- **AuditLog action 식별자**: `retry_skip_dedup` (operator='system_dlq', resourceId=eventId)
- **incident-log 박제 의무**: dedup 차단 시 logger.log 동반 (sensor-adversarial-pre-commit P20)
- **DB schema 변경 0건**: 본 sprint = 의존성 1건 추가 (PaymentRepositoryPort) + 로직 1건 추가만
- **PAY-P3-A 정합 (이중 방어)**: PAY-P3-A는 `processNormalizedWebhook` 내부 사전 게이트 (line 187-204) — 본 sprint는 retry 진입 자체를 차단 → payment.usecase 사전 게이트는 0건 호출 → 이중 방어 정합

### 검증 게이트

- jest server: `webhook-retry.job.spec.ts` PAY-P3-C describe (≥ 6 it)
- sensor: `sensor-retry-dedup.sh` (5 검증)
- eval: `regression-67-retry-dedup.json`

### 변경 시 동시 갱신 대상

- `grimoire-server/src/application/payment/webhook-retry.job.ts` (DI + 사전 게이트 + 통계)
- `grimoire-server/src/application/payment/webhook-retry.job.spec.ts` (≥ 6 it)
- `grimoire-server/src/app.module.ts` (PaymentRepositoryPort 주입 정합 검증 — 기존 박제됨, WebhookRetryJob provider 영역만 정합 검증)
- `grimoire-server/docs/api-contract.md` (webhook 처리 상태 표 retry_skip_dedup 박제)
- `grimoire-server/docs/data-model.md` (AuditLog action 표 — retry_skip_dedup 추가)
- `grimoire-server/SECURITY.md §3` (결제 원자성 영역 본 sprint dedup 패턴 박제)
- `grimoire-server/ADR.md` (Retry dedup 결정 박제)
- `eval/tasks/regression-67-retry-dedup.json`
- `.claude/scripts/sensor-retry-dedup.sh`

### 변경 이력

- 2026-05-09 #10_8 PAY-P3-C: 신설 — PAYMENT_AUDIT §1 모순-D (WebhookRetryJob ↔ ReconciliationJob 커버리지 겹침) 차단. webhook-retry.job 사전 dedup 게이트 (PaymentRepositoryPort 주입 + payment.status='completed'/'refunded'/'partial_refunded' 체크). DB schema 변경 0건. PAY-P3-A 정합 (이중 방어). 정본: `reports/sprint-pay-p3-c-retry-dedup-progress.md` (Generator 진입 후 박제).
```

**예상 shared-contracts 변동**: §1~22 (PAY-P3-A 종료 직후) → **§1~23**

### 5-5. 검증 게이트 종합

| 게이트 | 통과 기준 |
|---|---|
| jest server | 631 → 637+ PASS (회귀 0) |
| eval regression | 66 → 67 PASS (재실행 검증) |
| sensor-retry-dedup.sh | PASS |
| sensor-payment-race-condition.sh (PAY-P3-A 회귀) | PASS |
| sensor-adversarial-pre-commit P16 (결제 원자성) | PASS |
| sensor-shared-contracts.sh | PASS (§23 박제 정합) |
| visual-canon-keeper | 면제 (UI 변경 0) |
| cost-accountant | 면제 (외부 API 0) |
| qa Evaluator | CONDITIONAL PASS 또는 PASS (AC 8건 채점) |

---

## §6 멀티에이전트 위임 매트릭스

### 6-1. 본 sprint 위임 순서 (책 Ch 16 Anthropic 3-에이전트 + GMP v2.2 정합)

```
[Step 1] 메인 (orchestration-decision skill) → 본 sprint = server agent 위임 가치 매트릭스 통과 (코드 변경 + spec + sensor + shared-contracts)
[Step 2] grimoire-planner (Initializer, 본 작업) → `.claude/state/sprint-pay-p3-c-retry-dedup-draft.md` 박제 + AC BDD 8건 박제
[Step 3] cost-accountant 면제 (외부 API 0)
[Step 4] visual-canon-keeper 면제 (UI 변경 0)
[Step 5] grimoire-server (Generator) → 본 sprint 영역:
  - webhook-retry.job.ts DI + 사전 dedup 게이트 + 통계 박제
  - webhook-retry.job.spec.ts ≥ 6 it 신설
  - sensor 신설 + eval task 신설 + shared-contracts §23 신설
  - reports/sprint-pay-p3-c-retry-dedup-progress.md 갱신 (Initializer 산출 영역에서 인계)
  - 핵심 docs 갱신 (api-contract.md / data-model.md / SECURITY.md / ADR.md)
[Step 6] verification-before-completion skill + sensor 회귀 검증
[Step 7] socratic-self-critique skill (14 질문 + Ambiguity ≤ 0.2)
[Step 8] requesting-code-review skill (12 항목 체크리스트)
[Step 9] sensor-adversarial-pre-commit (19 principles, FAIL 0건 강제)
[Step 10] grimoire-qa (Evaluator) → reports/QA_REPORT.md (AC 8건 채점 + jest 637+ + eval 67 + sensor 41 + shared-contracts §23 검증)
[Step 11] commit + push develop (메인 직접, 화이트리스트 hook 통과)
[Step 12] memory 박제 (Stop hook 강제 + incident-log)
```

### 6-2. 위임 매트릭스 (각 agent 책임 영역)

| Agent | 책임 영역 | 산출물 |
|---|---|---|
| **grimoire-planner (Initializer, 본 작업)** | Sprint 계약 13 섹션 + AC BDD 8건 박제 | `.claude/state/sprint-pay-p3-c-retry-dedup-draft.md` (본 파일) |
| cost-accountant | **면제** (외부 API 0, 마진 영향 0) | 면제 박제 |
| visual-canon-keeper | **면제** (UI 변경 0) | 면제 박제 |
| **grimoire-server (Generator)** | 코드 + spec + sensor + eval + shared-contracts §23 | `reports/sprint-pay-p3-c-retry-dedup-progress.md` 갱신 + commit |
| **grimoire-qa (Evaluator)** | AC 8건 채점 + jest/eval/sensor 회귀 + 거짓말 차단 (qa 독립 재실행 + 직접 Read) | `reports/QA_REPORT.md` |
| 메인 직접 | commit + push develop (화이트리스트 통과 영역) | 2 레포 develop branch (server + claude-docs) |

### 6-3. infrastructure agent 결합 (HANDOVER §1.6 정합)

- 본 sprint = DB 마이그레이션 0건 → grimoire-infrastructure agent **면제**
- DB schema 변경 시점 (PAY-P3-E FK cascade) = 별도 sprint에서 위임

### 6-4. 케이스 처리 매트릭스 (재시작 플랜 §2-2 정합)

본 sprint 진행 중 결함 발견 시 케이스 처리:

| 케이스 | 트리거 | 처리 흐름 |
|---|---|---|
| 케이스 1 (agent 거부) | grimoire-server agent가 `webhook-retry.job.ts` 책임 영역 외부 명시 거부 | 사용자 직접 영역: PP-13 우회 함수 복원 → agent 정의 책임 영역 명시 → 우회 함수 제거 |
| 케이스 2 (agent 메인 전가 + 도메인 정합) | grimoire-server agent가 본 작업을 메인으로 전가 + payment 도메인 정합 | 사용자 직접 영역: PP-7 라우팅 매트릭스 영역 추가 → agent 정의 책임 영역 명시 → 우회 함수 제거 |
| 케이스 3 (agent isSidechain 결함) | Task tool 진입 시 PP-7 hook이 isSidechain=False로 검출 | 사용자 직접 영역: hook 디버깅 (재시작 플랜 §1-1 본질 결함 정합) |

---

## §7 incident-log 박제 의무 (Mitchell Ghostty 정합)

### 7-1. 본 sprint 진행 중 박제 의무 카테고리

각 카테고리 발견 시 **즉시 박제** (sensor-adversarial-pre-commit P20 + Constitution Principle 20 정합):

| 카테고리 | 박제 시점 | 본 sprint 예상 시나리오 |
|---|---|---|
| **retry_dedup_blocked** | 사전 dedup 게이트 차단 시 | AC-2, AC-3, AC-4, AC-6 발동 시점 |
| **retry_dedup_false_positive** | dedup 게이트가 정상 retry를 차단한 시 (false positive) | AC-1 회귀 발견 시 |
| **agent_failure** | server agent commit/push 0건인데 자율 시도 | Generator 진입 시 |
| **documentation_gap** | shared-contracts §23 박제 누락 발견 시 | 본 sprint 진행 중 |
| **dev_verification_skip** | code spec PASS만 박제 후 운영 영향 0 보고 | qa Evaluator 채점 시점 |
| **false_report_caught** | 거짓 보고 사슬 발견 시 | 모든 단계 |
| **guard_bypass_attempt** | sensor 우회 시도 시 | sensor-adversarial-pre-commit FAIL |

### 7-2. 박제 명령 표준 (sensor-adversarial-pre-commit 정합)

```bash
bash .claude/scripts/incident-log.sh \
  --category=retry_dedup_blocked \
  --severity=info \
  --source=webhook-retry-job \
  --description="PAY-P3-C AC-2 차단 — payment.status=completed 상태 retry 시도 차단 eventId=evt_..."
```

### 7-3. incident-log 검증 게이트

- qa Evaluator는 본 sprint 진행 중 박제된 incident-log를 직접 Read 후 QA_REPORT 박제
- sensor-adversarial-pre-commit은 incident-log 부재 시 FAIL (본 sprint 진행 중 retry_dedup_blocked 카테고리 ≥ 1건 박제 필수)

---

## §8 dev 작동 검증 영역 (메인 자율 vs 사용자 영역 분리)

### 8-1. 메인 자율 영역 (가드 통과)

| # | 검증 영역 | 명령 | 기대 |
|---|---|---|---|
| 1 | jest server 회귀 | `cd grimoire-server && npm test` | 637+ PASS |
| 2 | eval regression-52~67 | `bash eval/scripts/eval-runner.sh --filter regression-` | 67/67 PASS |
| 3 | sensor-retry-dedup.sh | `bash .claude/scripts/sensor-retry-dedup.sh` | PASS |
| 4 | sensor-payment-race-condition.sh (PAY-P3-A 회귀) | `bash .claude/scripts/sensor-payment-race-condition.sh` | PASS |
| 5 | sensor-adversarial-pre-commit P16 | `bash .claude/scripts/sensor-adversarial-pre-commit.sh` | PASS |
| 6 | sensor-shared-contracts.sh | `bash .claude/scripts/sensor-shared-contracts.sh` | PASS (§23 박제 정합) |
| 7 | dev API 회귀 (curl) | `curl -fs https://dev-api.grimoire-book.com/health` | HTTP 200 |
| 8 | dev cron logs 박제 (선택) | `az containerapp logs show ... \| grep WebhookRetryJob` | 5분 주기 발동 정상 + `dedup=N` 통계 박제 |

### 8-2. 사용자 명시 권한 영역 (자격증명 영역)

| # | 검증 영역 | 준비 | 명시 키워드 |
|---|---|---|---|
| 1 | dev S1 boost + retry queue 시뮬 + dedup 발동 직접 검증 | DB seed (payment.status='pending' + retry queue 1건) → ReconciliationJob 발동 → 5분 후 WebhookRetryJob 진입 → dedup 발동 logs 박제 | `dev retry dedup 시뮬 진행` |
| 2 | Polar webhook 의도적 실패 + retry queue 누적 → boost 후 dedup | Polar dashboard 또는 HMAC mock + reconciliation cron 발동 후 retry cron 시점 | `Polar webhook + reconciliation 시뮬 진행` |
| 3 | dev 24h 안정성 박제 후 prod 영역 | dev 회귀 0건 박제 후 | `prod main 머지 진행` |

### 8-3. 자동 검증 영역 (sensor 영역)

- sensor-retry-dedup.sh = CI/CD pre-push hook 자동 검증
- eval regression-67 = sensor-eval-trend.sh 자동 검증
- jest server = pre-push hook 자동 검증

---

## §9 사용자 결정 영역 (메인 자율 진행 금지 영역)

### 9-1. main 머지 영역 (.githooks/AGENTS.md §1 정합)

- 본 sprint 진행 중 **develop push만** 자동 (2 레포 server + claude-docs)
- main 머지는 **per-repo 명시 승인** 필수
- 명시 키워드: `server main 머지 진행` / `claude-docs main 머지 진행`

### 9-2. dev curl 자격증명 영역

- dev S1 boost + retry queue 시뮬 = 메인 자율 진행 금지
- 사용자 명시: `dev retry dedup 시뮬 진행`

### 9-3. prod 배포 영역

- dev 24h 안정성 박제 후 사용자 명시 필요
- 명시 키워드: `prod 배포 진행` (현재 본 sprint = dev 배포만 자동)

### 9-4. DB schema 변경 영역 (P2 보류)

- 본 sprint 본질 = DB schema 변경 0건 + 의존성 1건 추가 (PaymentRepositoryPort) + 로직 1건 추가만
- advisory_lock + partial unique index = P2 보류 (replicas ≥2 시점, 별도 sprint)

---

## §10 Definition of Done (qa Evaluator 채점 기준)

### 10-1. 정량 KPI

- [ ] jest server **637+ PASS** (회귀 0)
- [ ] eval regression **67 PASS** (재실행 검증)
- [ ] sensor **41 PASS** (sensor-retry-dedup.sh 신설)
- [ ] shared-contracts **§23 박제** (RetryDeduplication)
- [ ] AC BDD **8건 PASS** (qa 독립 재실행 + 직접 Read 검증)
- [ ] incident-log **≥ 1건 박제** (retry_dedup_blocked 카테고리)

### 10-2. 정성 검증

- [ ] webhook-retry.job.ts에 `PaymentRepositoryPort` DI 주입 박제
- [ ] webhook-retry.job.ts retryDueWebhooks for-loop 진입 직전 사전 dedup 게이트 박제
- [ ] payment.status='completed' OR 'refunded' OR 'partial_refunded' 사전 게이트 박제
- [ ] dedup 차단 시 retryQueueRepo.deleteById 즉시 호출 박제 (markRetry 호출 0건)
- [ ] AuditLog operator='system_dlq' action='retry_skip_dedup' 박제
- [ ] logger.log 통계 `dedup=N` 추가 박제
- [ ] PAY-P3-A 사전 게이트와 이중 방어 정합 (retry 진입 차단 → payment.usecase 사전 게이트 호출 0건)
- [ ] sensor-adversarial-pre-commit P16 (결제 원자성) PASS

### 10-3. 산출물 박제

- [ ] **Draft commit** + push develop (`.claude/state/sprint-pay-p3-c-retry-dedup-draft.md` 박제)
- [ ] Generator (server agent) 진입 후 `reports/sprint-pay-p3-c-retry-dedup-progress.md` 신설 + 갱신
- [ ] qa Evaluator의 `reports/QA_REPORT.md` CONDITIONAL PASS 또는 PASS

### 10-4. 회귀 차단

- [ ] PAY-P0-1 (webhook event_id 멱등성) 회귀 0
- [ ] PAY-P0-2 (PG↔DB 정합성 cron) 회귀 0
- [ ] PAY-P0-3 (운영자 수동 크레딧 UI) 회귀 0
- [ ] PAY-P1-1 (Refund 4분기 처리) 회귀 0
- [ ] PAY-P1-3 (결제 실패 retry + cleanup cron) 회귀 0
- [ ] PAY-P2-1 (부분 환불 비율) 회귀 0
- [ ] PAY-P2-2 (Webhook DLQ + retry) 회귀 0 — **본 sprint 핵심 정합 영역**
- [ ] PAY-P2-3 (SmsServicePort 캡슐화) 회귀 0
- [ ] PAY-P2-4 (AdminAuditLog beforeState/afterState) 회귀 0
- [ ] PAY-P3-A (Race condition 사전 게이트 + CAS 패턴) 회귀 0

---

## §11 회귀 차단 영역 (eval regression-52~66 회귀 0 보장)

### 11-1. 결제 회귀 매트릭스

| eval task | sprint | 본 sprint 영향 | 회귀 검증 |
|---|---|---|---|
| regression-52 | PAY-P0-1 webhook event_id 멱등성 | webhook_events @unique 회귀 0 | 자동 |
| regression-53 | PAY-P0-2 PG↔DB 정합성 cron | reconciliation cron 회귀 0 | 자동 |
| regression-54 | PAY-P0-3 admin grant credits | admin UI 회귀 0 | 자동 |
| regression-55 | PAY-P1-1 refund atomicity | refundPaymentAtomically CAS 패턴 회귀 0 | 자동 |
| regression-57 | PAY-P1-3 payment retry reuse | findReusablePendingPayment 회귀 0 | 자동 |
| regression-58 | PAY-P2-1 부분 환불 비율 | partial_refunded 사전 게이트 회귀 0 | 자동 |
| regression-59 | PAY-P2-2 webhook DLQ + WebhookRetryJob | **본 sprint 사전 dedup 게이트 추가 — 정상 retry (pending) 회귀 0 보장 강화** | 자동 + AC-1 |
| regression-60~65 | PAY-P2-3/4 + 기타 | SMS/audit 회귀 0 | 자동 |
| regression-66 | PAY-P3-A race condition | payment.status 사전 게이트 + CAS 회귀 0 | 자동 |
| regression-67 | **PAY-P3-C 본 sprint** | 신설 | 신설 |

### 11-2. 강화 영역 (회귀 0 + 보강)

- **regression-59 (PAY-P2-2)**: webhook-retry.job 사전 dedup 게이트 추가 → 기존 정상 retry (pending 상태) 시나리오 회귀 0 + dedup 차단 추가 (AC-2/AC-3/AC-4)
- **regression-66 (PAY-P3-A)**: 본 sprint와 이중 방어 정합 → PAY-P3-A `processNormalizedWebhook` 사전 게이트는 본 sprint 진입 차단 후 0건 호출 (회귀 0)

---

## §12 변경 이력

- **2026-05-09 #10_8 본 세션** — 본 Sprint 계약 신설 (`.claude/state/` Draft 박제 영역, PP-13 화이트리스트 우회). 입력 자료 7건 (sprint-pay-p3-master-plan-draft.md + sprint-pay-p3-restart-plan-draft.md + sprint-pay-p3-a-race-condition-draft.md + PAYMENT_AUDIT-2026-05-07.md + webhook-retry.job.ts + payment-reconciliation.job.ts + shared-contracts §11/§12/§22) 직접 Read 후:
  - **§0 한 줄 요약** + **§1 배경** (모순-D raw 인용 + 메인 정밀 검증 결과 — 두 cron job 코드 직접 분석) + **§2 목표** (KPI 5건 + 비목표 7건) + **§3 변경 영역** (server 핵심 코드 4건 + 신설 4건 + 회귀 차단 6건) + **§4 AC BDD 8건** (qa Evaluator 채점 정본 형식) + **§5 검증 매트릭스** (jest ≥6 it / eval task 1건 / sensor 1건 / shared-contracts §23) + **§6 멀티에이전트 위임** (책 Ch 16 정합 + 케이스 처리 매트릭스) + **§7 incident-log 박제 의무** (Mitchell Ghostty 정합) + **§8 dev 검증 영역** (메인 자율 + 사용자 영역 분리) + **§9 사용자 결정 영역** (main 머지 + dev curl + prod 배포 + DB schema P2) + **§10 Definition of Done** (정량 + 정성 + 산출물 + 회귀) + **§11 회귀 차단 영역** (eval 52~66 회귀 0 + PAY-P2-2/PAY-P3-A 강화) + **§12 변경 이력** 박제.
  - **메인 정밀 발견 (직접 Read)**: 모순-D 본질 = `webhook-retry.job.ts:82` `processNormalizedWebhook` 호출 시 사전 dedup 0건. ReconciliationJob S1 boost (line 117-122) 후 payment.status='completed' 상태에서 retry queue due 행 5분 cron 재처리 시도. `processNormalizedWebhook` 내부 `payment.status='completed'` 게이트 (line 175-186)로 멱등성은 보장되지만, **호출 자체가 5분마다 발생** → DB I/O + audit log noise. 또한 retry 처리 중 다른 exception 발생 시 markRetry → MAX_RETRY (10회) 누적 → permanent_failed 박제 = **거짓 audit log 박제 가능성**. 본 sprint 핵심 = WebhookRetryJob retry 진입 직전 `findByExternalTransactionId` 1회 추가 + payment.status 사전 dedup 게이트. PAY-P3-A 정합 (이중 방어 — retry 진입 차단 → payment.usecase 사전 게이트 호출 0건).

---

## 참조 (file:line)

### 정본 문서

- `.claude/state/sprint-pay-p3-master-plan-draft.md` — PAY-P3 마스터 플랜 (본 sprint 위치 박제, Phase 1 두 번째 권장)
- `.claude/state/sprint-pay-p3-restart-plan-draft.md` — 재시작 플랜 (케이스 처리 매트릭스 정합)
- `.claude/state/sprint-pay-p3-a-race-condition-draft.md` — PAY-P3-A Sprint 계약 (정합 패턴 정본)
- `research/PAYMENT_AUDIT-2026-05-07.md §1` — 모순-D raw + 두 cron 정합 표
- `.claude/shared-contracts.md §11` — WebhookEventIdempotency (인접 영역, eventId @unique 멱등성)
- `.claude/shared-contracts.md §12` — PaymentReconciliation (인접 영역, S1 boost 로직)
- `.claude/shared-contracts.md §22` — PaymentRaceCondition (정합 영역, payment.usecase 사전 게이트)
- `.claude/shared-contracts.md §23` (예정) — RetryDeduplication 신설 정본 (본 sprint 산출)

### 핵심 코드 (server, 직접 Read 검증)

- `application/payment/webhook-retry.job.ts:55-124` `retryDueWebhooks` @Cron 5분 — **본 sprint 사전 dedup 게이트 추가 영역**
- `application/payment/webhook-retry.job.ts:43-50` constructor DI — **본 sprint PaymentRepositoryPort 주입 추가 영역**
- `application/payment/webhook-retry.job.ts:78-113` for-loop 진입 직후 — **본 sprint 사전 dedup 게이트 진입점**
- `application/payment/webhook-retry.job.ts:115-117` logger.log 통계 — **본 sprint dedup=N 추가 영역**
- `application/payment/webhook-retry.job.ts:142-171` markPermanentFailed + AuditLog — **본 sprint 정합 영역 (변경 0건, retry_skip_dedup 별도 함수 또는 인라인)**
- `application/payment/payment-reconciliation.job.ts:117-122` S1 boost — **본 sprint 정합 영역 (변경 0건)**
- `application/payment/payment.usecase.ts:147-204` `processNormalizedWebhook` — **본 sprint 정합 영역 (변경 0건, PAY-P3-A 사전 게이트 호출 0건)**
- `domain/port/outbound/payment-repository.port.ts` `findByExternalTransactionId` 시그니처 — **본 sprint 시그니처 변경 0건 (기존 시그니처 재사용)**

### Sprint progress 박제 영역 (본 sprint 신설 후 영역)

- `reports/sprint-pay-p3-c-retry-dedup-progress.md` (Generator 진입 후 신설)

### 관련 sprint progress (완료)

- `reports/sprint-pay-p0-1/2/3-progress.md`
- `reports/sprint-pay-p1-1-refund-progress.md`
- `reports/sprint-pay-p1-3-retry-policy-progress.md`
- `reports/sprint-pay-p2-1/2/3/4-*.md`
- `reports/sprint-pay-p3-a-race-condition-progress.md` (Generator 진입 영역, PAY-P3-A 종료 직후 박제 영역)

### 관련 정본 문서 (Generator가 갱신할 영역)

- `grimoire-server/docs/api-contract.md` — webhook 처리 상태 표 + retry_skip_dedup 박제
- `grimoire-server/docs/data-model.md` — AuditLog action 표 + retry_skip_dedup 추가
- `grimoire-server/SECURITY.md §3` — 결제 원자성 영역 dedup 패턴
- `grimoire-server/ADR.md` — Retry dedup 결정 박제 (옵션 A/B/C 비교)
- `grimoire-server/CLAUDE.md §9` — 결제/크레딧 원자성 절대 규칙 (정합 검증)

---

**상태**: Sprint 계약 13 섹션 + AC BDD 8건 박제 완료 (`.claude/state/` Draft 영역, PP-13 화이트리스트 통과). **다음 단계 = grimoire-server agent (Generator) 위임 진입**. 본 Draft가 server agent 진입 정본 — 모호 영역 0건. shared-contracts §23 RetryDeduplication 신설 영역 박제. 사용자 명시 후 즉시 server agent (Generator) 위임 → qa Evaluator 위임 → 메인 commit/push 진행.
