# Sprint PAY-P2-2 webhook DLQ (Postgres RetryQueue) — 정본 (sprint #10_7)

> **유형**: 결제 시스템 PAY-P2 2단계 — webhook 처리 실패 재시도 큐
> **소요**: ~3시간 (자율 진행 완료, 마스터 플랜 ~4h 추정 대비 효율)
> **외부 인프라 의존**: 0건 (Postgres만 — 절대 규정 0-1 정합)
> **종료 조건**: AC-1~AC-9 모두 PASS + 회귀 차단 sensor + shared-contracts §18

---

## §1. 사용자 명시 트랙 진입

- **사용자 명시**: "결제시스템 고도화 쭉 진행" + "1" (PAY-P2-2 자율 즉시 진입)
- **마스터 플랜**: `reports/PAY-P2-MASTER-PLAN.md` §4 (P2-2 자율 가능 박제)
- **PAY-P2-1 호환성**: shared-contracts §17 PartialRefund와 독립 (env 비활성화 게이트로 리스크 격리)

---

## §2. AC (Acceptance Criteria) — 9건

### AC-1. Schema 모델 + Migration

`grimoire-server/prisma/schema.prisma`:

```prisma
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
```

Migration: `prisma/migrations/20260505020000_add_webhook_retry_queue/migration.sql`

**검증**: ✅ schema + migration + Prisma client generate 성공

### AC-2. Port 인터페이스

`grimoire-server/src/domain/port/outbound/webhook-retry-queue-repository.port.ts`:
- `upsert` (P2002 race 안전, null 반환)
- `findDue(now, limit)` (ORDER BY nextRetryAt LIMIT N)
- `deleteById`
- `markRetry(id, error, nextRetryAt)` (retryCount++)
- `findByEventId`

**검증**: ✅ 5 메서드 정합

### AC-3. Repository 구현

`grimoire-server/src/adapter/outbound/persistence/prisma-webhook-retry-queue.repository.ts`:
- P2002 (Prisma.PrismaClientKnownRequestError) catch → null 반환
- markRetry는 `retryCount: { increment: 1 }` + lastError 500자 truncate
- findDue는 `where: { nextRetryAt: { lte: now } }` + `orderBy: { nextRetryAt: 'asc' }` + `take: limit`

**검증**: ✅ P2002 race 안전 + Prisma 표준 패턴

### AC-4. WebhookRetryJob @Cron 5분

`grimoire-server/src/application/payment/webhook-retry.job.ts`:
- `@Cron('0 */5 * * * *')` 5분 주기
- isRunning lock (in-memory)
- BATCH_SIZE=100
- MAX_RETRY=10
- exp backoff 매트릭스: 1m → 5m → 30m → 2h → 12h → 24h
- WEBHOOK_RETRY_DISABLED env 비활성화 게이트
- AuditLog operator='system_dlq' + action='webhook_permanent_failed'

**검증**: ✅ Job 정상 박제 + cron expression 안전 (주석 안 `*/` escape)

### AC-5. payment.usecase 보강

`grimoire-server/src/application/payment/payment.usecase.ts`:
- `processWebhook` → `processNormalizedWebhook` 분리 (retry 시점 verify 우회)
- `enqueueWebhookRetry(event, eventId)` 헬퍼 (Optional 의존 — 미주입 시 회귀 보존)
- success 트랜잭션 실패 분기 + cancel 환수 실패 분기 양쪽에서 호출
- return type 명시 (union 통합 — spec 회귀 보존)

**검증**:
- ✅ processNormalizedWebhook 분리 박제
- ✅ enqueueWebhookRetry 호출 ≥2건 (success + cancel 실패 분기)
- ✅ Optional 주입 — payment.usecase.spec 회귀 보존 (mock 미주입 시 무동작)

### AC-6. spec 8 it (webhook-retry.job.spec.ts)

1. ✅ 1/8: nextRetryAt 도래한 row 0건이면 paymentUseCase 호출 0회
2. ✅ 2/8: 성공 시 paymentUseCase 호출 + queue row deleteById
3. ✅ 3/8: 실패 시 retryCount++ + lastError + nextRetryAt 백오프 갱신
4. ✅ 4/8: MAX_RETRY=10 초과 시 permanent_failed 박제 + queue 삭제 + AuditLog system_dlq
5. ✅ 5/8: isRunning lock — 동시 실행 차단
6. ✅ 6/8: 다중 row (3건) 순차 처리
7. ✅ 7/8: WEBHOOK_RETRY_DISABLED=1 env 시 즉시 return
8. ✅ 8/8: 백오프 스케줄 매트릭스 (1m/5m/30m/2h/12h/24h) 정합

**실행 결과**: 8/8 PASS

### AC-7. app.module 등록

```typescript
import { WebhookRetryJob } from '@application/payment/webhook-retry.job'
import { PrismaWebhookRetryQueueRepository } from '@adapter/outbound/persistence/prisma-webhook-retry-queue.repository'

providers: [
  ...,
  WebhookRetryJob,
  { provide: 'WebhookRetryQueueRepositoryPort', useClass: PrismaWebhookRetryQueueRepository },
]
```

**검증**: ✅ DI 등록 정합

### AC-8. sensor + regression-62

- `.claude/scripts/sensor-webhook-dlq.sh` (12 검증, 12/12 PASS)
- `eval/tasks/regression-62-webhook-dlq.json` (12 criteria)

### AC-9. 정본 갱신

- ✅ `.claude/shared-contracts.md` §18 WebhookDLQ 신설
- ✅ `reports/PAY-P2-MASTER-PLAN.md` §4 사전 박제됨
- ✅ HARNESS_ENGINEERING.md Sensors §14.4 자동 갱신 (commit 시 자동)

---

## §3. 외부 의존 0건 검증

```bash
grep -rEi 'redis|servicebus|kafka|sqs|rabbitmq' \
  grimoire-server/src/application/payment/webhook-retry.job.ts \
  grimoire-server/src/adapter/outbound/persistence/prisma-webhook-retry-queue.repository.ts \
  grimoire-server/src/domain/port/outbound/webhook-retry-queue-repository.port.ts
# 기대: 0건 (Postgres only)
```

---

## §4. 회귀 차단 정합

| sensor | 결과 | 비고 |
|---|---|---|
| sensor-webhook-dlq | ✅ 12/12 PASS | 신규 박제 |
| sensor-partial-refund | ✅ 10/10 PASS | PAY-P2-1 회귀 보존 |
| sensor-payment-idempotency | ✅ PASS | PAY-P0-1 회귀 보존 |
| sensor-payment-reconciliation | ✅ PASS | PAY-P0-2 회귀 보존 |
| sensor-payment-retry-reuse | ✅ PASS | PAY-P1-3 회귀 보존 |
| sensor-refund-atomicity | ✅ PASS | PAY-P1-1 회귀 보존 |
| jest server | ✅ 591/591 PASS | webhook-retry.spec 8/8 + 기타 회귀 |
| tsc | ✅ 0 errors | strict 정합 |

---

## §5. 위험 시나리오 (해소된 것 vs 잔존)

| # | 시나리오 | PAY-P2-2 후 | 잔존 |
|---|---|---|---|
| 1 | webhook 단발 처리 실패 → 영구 손실 | ✅ 해소 (Polar 재전송 + 본 큐 자체 재시도 이중 보호) | — |
| 2 | DB 일시 장애 시 webhook 손실 | ✅ 해소 (next 5분 cron이 재시도) | — |
| 3 | 무한 재시도 루프 | ✅ 차단 (MAX_RETRY=10) | — |
| 4 | 동시 실행 race | ⚠️ in-memory lock (single replica) | replicas ≥2 시 advisory_lock 보강 (P3 보류) |
| 5 | 큐 row 무한 누적 | ✅ 차단 (성공 시 deleteById, MAX 초과 시도 deleteById) | — |
| 6 | 운영자 긴급 중단 | ✅ 보장 (WEBHOOK_RETRY_DISABLED=1 env) | — |

---

## §6. 사용자 결정 영역

| # | 항목 | 명령 |
|---|---|---|
| 1 | dev migration deploy | `cd grimoire-server && npx prisma migrate deploy` (또는 dev 자동 배포 시 자동 실행) |
| 2 | dev 검증: webhook 실패 시뮬 | DB 일시 장애 발생 + 5분 후 자동 재처리 박제 확인 (Container Apps 로그) |
| 3 | dev 검증: MAX_RETRY 도달 시 permanent_failed | 의도적 실패 webhook 11회 재시도 → AuditLog system_dlq row 박제 확인 |
| 4 | prod 배포 | `npx prisma migrate deploy && make deploy-prod` |
| 5 | replicas ≥2 시 advisory_lock 보강 진입 결정 | 운영 트래픽 증가 후 P3 sprint 진입 |
| 6 | WEBHOOK_RETRY_DISABLED=1 env 사전 박제 (긴급 차단용) | INFRASTRUCTURE.md 환경변수 표 참조 |

---

## §7. 다음 단계 — PAY-P2-3 SMS (BLOCKED)

**진입 게이트**: 절대 규정 0-1 (외부 API 신규 의존) **사용자 명시 해제 필요**

**참고 솔루션**:
- KAKAO Bizmessage (KRW, 한국 사용자 중심) — 추천
- NHN Cloud SMS (한국 SMS 표준)
- Twilio (USD, 글로벌)

**작업 영역**:
1. SmsServicePort 캡슐화 (NullSmsAdapter stub) — **자율 가능** (외부 API 결정 전)
2. 결제 완료/실패/환불 시 SMS 발송 트리거 — **자율 가능** (NullAdapter는 noop)
3. spec + sensor + regression task — **자율 가능**
4. 실 SMS adapter 구현 — **사용자 결정 후만**

EmailServicePort 패턴 정합 — Hexagonal Port 캡슐화 우선 박제 가능.

---

## §8. 검증 명령

```bash
cd /Users/sokol/Git/ProjectGrimoire

# PAY-P2-2 회귀 검증
bash .claude/scripts/sensor-webhook-dlq.sh
bash eval/scripts/eval-runner.sh tasks/regression-62-webhook-dlq.json

# server jest 591/591 PASS
cd grimoire-server
npx jest src/application/payment/webhook-retry.job.spec.ts
npx jest src/application/payment/payment.usecase.spec.ts  # 회귀 보존 확인

# 다른 sprint 회귀 보존
cd /Users/sokol/Git/ProjectGrimoire
bash eval/scripts/eval-runner.sh
bash .claude/scripts/sensor-adversarial-pre-commit.sh
```

---

## §9. 정본 정합

- `.claude/shared-contracts.md` §18 WebhookDLQ (인터페이스 정본)
- `reports/PAY-P2-MASTER-PLAN.md` §4 (마스터 플랜 정본)
- `reports/sprint-pay-p2-1-partial-refund-progress.md` (PAY-P2-1 정본 — 본 sprint와 독립)

---

마지막 업데이트: 2026-05-05 PAY-P2-2 자율 진행 완료
승격 원본: 사용자 명시 "1" (PAY-P2-2 자율 즉시 진입) + PAY-P2 마스터 플랜 §4
