# Sprint Progress — pay-p0-2-payment-reconciliation-cron

> **Sprint ID**: sprint-pay-p0-2-payment-reconciliation-cron
> **세션**: #10_7 PAY-P0-2 (PAYMENT_SYSTEM_PLAN §3-1 두 번째 항목)
> **Initializer**: grimoire-planner (책 Ch 16 Anthropic 3-에이전트 패턴 — 묶음 II 4회차)
> **작성일**: 2026-05-03
> **단일 진실**: 본 파일이 Generator (server / claude-docs) + Evaluator (qa) 모두의 작업 정본. 모호하면 본 파일 갱신 후 합의.
> **선행 Sprint**: PAY-P0-1 (sprint-pay-p0-1-webhook-event-id-idempotency-progress.md) — 산출물 체크리스트 [x] 박제 완료 (server commit `8c13103` + claude-docs `06de6c6`).

---

## 0. Goal — 한 줄

NestJS `@Cron('0 */10 * * * *')` 10분 주기로 Polar checkouts API와 DB Payment 테이블을 비교하여 **webhook 누락 자동 발견 + 자동 보정** + **사용자 신고 의존 0건**. CERTI_PROJ thermage-batch-api `@Cron('*/10 * * * * *')` 패턴(10초)을 Grimoire 결제 규모에 맞춰 10분으로 완화 차용. PG ↔ DB 정합성 검증 batch.

---

## 1. 배경 (메인 사전 파악 — 실측 박제)

### 1-1. 현재 갭 (PAYMENT_SYSTEM_PLAN §1-5 #2)

> **PG ↔ DB 정합성 검증 batch 부재** — Webhook 누락 발견 불가, 사용자 신고 의존. **운영 안정성 핵심**.

PAY-P0-1 (webhook event_id 멱등성)은 **중복 처리 차단**은 보장하지만, **Polar이 webhook을 아예 못 보내는 경우** (Polar 측 장애 / 네트워크 / Container Apps cold start 동안 timeout 등)는 여전히 영구 누락 가능. 사용자가 결제 후 "크레딧 안 들어왔다"고 CS 신고하기 전까지 운영자가 모름.

### 1-2. CERTI_PROJ 인용 패턴 (PAYMENT_SYSTEM_PLAN §11)

`/CERTI_PROJ/thermage-batch-api/src/modules/batch/schedules/batch.schedule.ts:17~37`:

```typescript
@Cron('*/10 * * * * *')   // 10초 주기 (의료 결제 시스템)
async syncBatch() {
  await this.usageCompleteBulkService.run()
}
```

`/CERTI_PROJ/thermage-batch-api/src/modules/batch/services/usage-complete-bulk.service.ts:27~100`:
- PG API list 호출 (페이지네이션 pageSize=100)
- DB 비교 + 차이점 자동 보정
- timeout 90s
- prev run lock check (동시 cron 실행 차단)

### 1-3. Grimoire 갭과 CERTI_PROJ 패턴 비교

| 항목 | CERTI_PROJ thermage-batch-api | Grimoire 권고 |
|---|---|---|
| Cron 주기 | 10초 (`*/10 * * * * *`) — 의료 결제 (실시간성 중요) | 10분 (`0 */10 * * * *`) — 크레딧 결제 (사용자 인내 가능). cost-accountant 결과 기반 최종 결정 |
| 페이지네이션 | pageSize=100 | limit=100 (Polar SDK 동일) |
| Timeout | 90s | 60s (Polar API list rate limit 영향 고려) |
| 동시 실행 차단 | prev run lock check | `@SchedulerRegistry` lock 또는 in-memory `isRunning` 플래그 |
| Checkpoint | DB row | `ReconciliationCheckpoint` (단일 row 유지) |
| 차이점 보정 | 자동 (status mismatch → DB 보정 + 알림) | 자동 (PG=succeeded + DB=pending → completePaymentAtomically) + AuditLog 박제 |

### 1-4. NestJS @nestjs/schedule 실측

`grimoire-server/package.json` 확인 필요:
- `@nestjs/schedule` 패키지가 미도입 시 추가 필수 (Generator가 `npm install --save @nestjs/schedule` 박제)
- `app.module.ts`에 `ScheduleModule.forRoot()` import 의무

### 1-5. Polar SDK list API 실측

`grimoire-server/src/adapter/outbound/payment/polar.adapter.ts:73` Polar SDK `polar.checkouts.create({...})` 호출 박제 확인 (PAY-P0-1 완료 시점 코드).
- `polar.checkouts.list({ ... })` API 사용 가능 여부는 Polar SDK 버전 (`@polar-sh/sdk@^0.x`) 확인 필요. Generator가 SDK 문서/소스 직접 확인 박제.
- 대안: `polar.orders.list({ ... })` API (order는 결제 완료된 checkout)

### 1-6. PaymentRepositoryPort 확장 필요 영역

`grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (PAY-P0-1 완료 후 시그니처):
- `findByExternalTransactionId(externalTransactionId: string)` ✅ 존재
- `findPendingPaymentsOlderThan(hours: number)` ❌ 신설 (PAY-P0-2)
- `expirePayment(paymentId: string)` ❌ 신설 (PAY-P0-2 — pending 만료 처리)

---

## 2. Scope

### 2-1. IN

| 항목 | 영역 | 파일 (예상 경로) |
|---|---|---|
| Polar SDK list API 어댑터 메서드 신설 | server | `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` (`listRecentCheckouts(since, limit)` 추가) |
| `PaymentGatewayPort.listRecentCheckouts` 시그니처 추가 | server | `grimoire-server/src/domain/port/outbound/payment-gateway.port.ts` |
| `ReconciliationCheckpoint` Prisma 모델 | server | `grimoire-server/prisma/schema.prisma` (단일 row 보장 — `id` PK + `lastRunAt`) |
| Prisma 마이그레이션 | server | `grimoire-server/prisma/migrations/{ts}_add_reconciliation_checkpoint/migration.sql` |
| `ReconciliationCheckpointRepositoryPort` | server | `grimoire-server/src/domain/port/outbound/reconciliation-checkpoint-repository.port.ts` (신설) |
| Prisma 어댑터 구현 | server | `grimoire-server/src/adapter/outbound/persistence/prisma-reconciliation-checkpoint.repository.ts` (신설) |
| `PaymentRepositoryPort.findPendingPaymentsOlderThan` 추가 | server | `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` |
| `PaymentRepositoryPort.expirePayment` 추가 | server | 동상 |
| Prisma payment 어댑터 확장 | server | `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` |
| **`PaymentReconciliationJob` 신설** | server | `grimoire-server/src/application/payment/payment-reconciliation.job.ts` (`@Injectable` + `@Cron('0 */10 * * * *')`) |
| Job spec | server | `grimoire-server/src/application/payment/payment-reconciliation.job.spec.ts` (4 시나리오 + lock check + checkpoint 갱신) |
| `app.module.ts` DI 바인딩 + `ScheduleModule.forRoot()` | server | `grimoire-server/src/app.module.ts` |
| `@nestjs/schedule` 의존성 추가 (미도입 시) | server | `grimoire-server/package.json` |
| AdminAuditLog 활용 — `operator='system_reconciliation'` | server | 본 job 내부 (기존 `audit-log.service.ts` 그대로 활용) |
| 정본 문서 | server | `docs/api-contract.md` (내부 cron 명세 박제) + `docs/data-model.md` (ReconciliationCheckpoint) + `SCHEMA.md` + `MIGRATION.md` + `TECH_STATUS.md` + `CHANGELOG.md` |
| sensor 신설 | claude-docs | `.claude/scripts/sensor-payment-reconciliation.sh` |
| shared-contracts §12 신설 | claude-docs | `.claude/shared-contracts.md` (PaymentReconciliation 인터페이스) |
| eval regression | claude-docs | `eval/tasks/regression-53-payment-reconciliation.json` |

### 2-2. OUT

- **운영자 수동 지급 web UI** (PAY-P0-3 — 별도 Sprint, 본 Sprint 후행)
- **Refund 정밀 처리** (PAY-P1-1 — refundPaymentAtomically. 본 Sprint는 refund mismatch 발견 시 logger.warn + AuditLog만, 실제 환수 0건)
- **이메일 알림** (PAY-P1-2 — refund mismatch 시 운영자 알림은 logger 기반, 슬랙/이메일은 P1로 분리)
- **Bull/BullMQ 큐 도입** (P2 — 본 Sprint는 NestJS @Cron 단독)
- **Polar Subscription 정합성** (P1 — 작업 A 결합. 본 Sprint는 일회성 결제 checkouts/orders만 대상)
- **PROD 데이터 backfill** (PROD에 누락된 webhook은 cron 첫 실행 시점부터 자동 보정 — Generator가 운영자 안내 박제)
- **server 외 레포 (web)** — 본 Sprint 100% server + claude-docs (web 변경 0건)
- **외부 알림 채널 (슬랙/디스코드)** — logger.warn만 (운영자가 Container Apps 로그 모니터링 의무 — INFRASTRUCTURE.md 갱신)
- **HTTP endpoint 노출** (`POST /internal/payment-reconciliation/run` 수동 트리거는 PAY-P0-2 OUT — Generator가 `app.module` `imports`에서 controller 미박제. cron 단독)

---

## 3. 결정 사항 (Initializer 최종)

### 3-1. 방향 결정

| 방향 | 채택 | 사유 |
|---|---|---|
| **A. NestJS @Cron + ReconciliationCheckpoint 단일 row** | ✅ **채택** | 인프라 추가 0건. PostgreSQL row 1개로 lastRunAt 박제. 책 Ch 16 "shared state via DB" 정합. |
| B. Bull/BullMQ + Redis | ❌ 기각 | Redis 인프라 미도입 (Azure Container Apps 단일). PAY-P2로 분리. |
| C. cron 외부 호출 (GitHub Actions schedule) | ❌ 기각 | Container Apps cold start 시 첫 호출 timeout. Container 내부 cron이 더 안정. |
| D. 메모리 lastRunAt 변수 | ❌ 기각 | replicas ≥2 시 정합성 깨짐. 컨테이너 재시작 시 손실. |

### 3-2. ReconciliationCheckpoint 모델 (정본)

```prisma
model ReconciliationCheckpoint {
  id              String   @id @default("singleton")  // 단일 row 강제 — 항상 id='singleton'
  lastRunAt       DateTime @map("last_run_at") @db.Timestamptz(3)
  processedCount  Int      @default(0) @map("processed_count")  // 마지막 실행에서 처리한 row 수
  boostCount      Int      @default(0) @map("boost_count")      // 자동 보정한 row 수
  mismatchCount   Int      @default(0) @map("mismatch_count")   // refund mismatch 발견 row 수
  expireCount     Int      @default(0) @map("expire_count")     // pending 만료 처리 row 수
  errorMessage    String?  @map("error_message")
  updatedAt       DateTime @updatedAt @map("updated_at") @db.Timestamptz(3)

  @@map("reconciliation_checkpoints")
}
```

**핵심**: `id` default `"singleton"` + 마이그레이션에서 INSERT seed 1회 → 항상 1 row 보장. cron이 항상 같은 row를 update.

### 3-3. PaymentReconciliationJob 흐름 (정본)

```
1. 시작: lockCheck (in-memory `isRunning` 플래그) — true면 즉시 return + logger.warn
2. lastRunAt 조회 (ReconciliationCheckpoint.id='singleton')
3. polar.adapter.listRecentCheckouts(since: lastRunAt, limit: 100)
   - 페이지네이션: 100 초과 시 cursor 활용 (Polar SDK paging spec)
4. 각 checkout 순회:
   4-a. DB findByExternalTransactionId(checkout.id)
   4-b. 4 시나리오 분기:
        S1. PG=succeeded + DB=pending → completePaymentAtomically + AuditLog `boost`
        S2. PG=refunded + DB=completed → logger.warn + AuditLog `refund_mismatch` (P1-1에서 환수)
        S3. PG=NotFound + DB=pending (24h 이상 경과) → expirePayment + AuditLog `expire`
        S4. PG ↔ DB 정합 → skip (counter += 1)
5. checkpoint 갱신 (lastRunAt = now, processedCount/boostCount/mismatchCount/expireCount)
6. lockCheck 해제 (finally 블록)
7. 예외 발생 시: errorMessage 박제 + lockCheck 해제 + logger.error
```

### 3-4. AuditLog operator 박제 정책

모든 자동 보정 action은 AuditLog에 `operator='system_reconciliation'` (string) 박제. PAY-P0-1의 `audit-log.service.ts` 그대로 활용:

| action | targetId | detail |
|---|---|---|
| `reconciliation_boost` | paymentId | `{ reason: 'webhook_missed', polarStatus: 'succeeded', dbStatus: 'pending', credits: N }` |
| `reconciliation_refund_mismatch` | paymentId | `{ reason: 'pg_refunded_db_completed', polarStatus: 'refunded', dbStatus: 'completed', requiresManualRefund: true }` |
| `reconciliation_expire` | paymentId | `{ reason: 'pending_24h_no_pg_record', dbStatusBefore: 'pending', dbStatusAfter: 'expired' }` |

### 3-5. cron 주기 — cost-accountant 결과 대기

- **임시 기본값**: `'0 */10 * * * *'` (10분 주기)
- **확정 조건**: cost-accountant가 Polar API rate limit 조사 완료 시 본 §3-5 갱신 (사용자 또는 메인이 SendMessage로 결과 전달).
- **rate limit 추정**:
  - Polar API rate limit 미공개 → researcher 위임 (병렬 진행 중)
  - 추정 (보수): 100 req/min → 10분 주기면 1 req/cron, 안전 마진 100배
  - 예상 비용: Polar API call 비용 0 (Polar는 MoR — API call 무과금 정책)
- **cron 주기 변경 절차**:
  1. cost-accountant 보고서 수신
  2. 본 progress.md §3-5 갱신 (예: `'0 */5 * * * *'` 5분으로 단축 또는 `'0 0 */1 * * *'` 1시간으로 완화)
  3. `payment-reconciliation.job.ts` `@Cron(...)` 데코레이터 갱신
  4. AC-7 명령 stdout 박제 (`grep '@Cron' payment-reconciliation.job.ts`)

### 3-6. ReconciliationCheckpointRepositoryPort 시그니처

```typescript
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
```

### 3-7. PaymentGatewayPort 확장 (listRecentCheckouts)

```typescript
export interface NormalizedCheckout {
  externalTransactionId: string  // Polar checkout.id
  status: 'succeeded' | 'refunded' | 'failed' | 'open'
  amount: number                  // KRW
  metadata?: Record<string, unknown>
  createdAt: Date
}

export interface PaymentGatewayPort {
  // 기존 시그니처 +
  listRecentCheckouts(since: Date, limit: number): Promise<NormalizedCheckout[]>
}
```

---

## 4. Acceptance Criteria (AC) — 7건, Ambiguity ≤ 0.1

각 AC는 **실측 검증 가능한 raw stdout / grep 결과**로 증명. Generator는 본 AC를 충족하지 못하면 작업 미완료 박제 (DEV_REPORT.md에 raw stdout 박제).

### AC-1: PaymentReconciliationJob 클래스 신설 (@Injectable + @Cron) + DI 등록

**검증 명령**:
```bash
cd /Users/sokol/Git/ProjectGrimoire/grimoire-server
test -f src/application/payment/payment-reconciliation.job.ts
grep -nE '^\s*@Injectable\s*\(' src/application/payment/payment-reconciliation.job.ts
grep -nE "^\s*@Cron\s*\(" src/application/payment/payment-reconciliation.job.ts
grep -n 'PaymentReconciliationJob' src/app.module.ts
grep -n "ScheduleModule.forRoot" src/app.module.ts
grep -n "@nestjs/schedule" package.json
```

**기대 raw 출력**:
- 파일 존재
- `@Injectable()` 1건
- `@Cron('0 */10 * * * *')` 또는 본 progress.md §3-5에서 변경된 cron expression 1건
- `app.module.ts`에 `PaymentReconciliationJob` 1건 이상 (providers 또는 imports)
- `app.module.ts`에 `ScheduleModule.forRoot()` 1건
- `package.json`에 `@nestjs/schedule` 의존성 1건

### AC-2: Polar list API 호출 + 페이지네이션 (since + limit=100) 정합 (mock spec)

**검증 명령**:
```bash
cd /Users/sokol/Git/ProjectGrimoire/grimoire-server
grep -nE 'listRecentCheckouts' src/domain/port/outbound/payment-gateway.port.ts
grep -nE 'listRecentCheckouts' src/adapter/outbound/payment/polar.adapter.ts
grep -nE 'listRecentCheckouts|since|limit:\s*100' src/application/payment/payment-reconciliation.job.ts
grep -nE 'listRecentCheckouts' src/application/payment/payment-reconciliation.job.spec.ts
```

**기대 raw 출력**:
- `payment-gateway.port.ts`에 `listRecentCheckouts(since: Date, limit: number)` 시그니처 박제
- `polar.adapter.ts` 구현체 박제 — Polar SDK list API 호출 + 페이지네이션 (cursor 또는 page) 처리
- job 내부에서 `listRecentCheckouts(checkpoint.lastRunAt, 100)` 호출 박제
- spec에서 mock `listRecentCheckouts` 사용

### AC-3: 4 시나리오 (pending→success boost / refunded mismatch / pending expiry / 정합) jest spec 검증

**검증 명령**:
```bash
cd /Users/sokol/Git/ProjectGrimoire/grimoire-server
grep -nE 'pending.*success|boost|completePaymentAtomically' src/application/payment/payment-reconciliation.job.spec.ts
grep -nE 'refund.*mismatch|refunded.*completed' src/application/payment/payment-reconciliation.job.spec.ts
grep -nE 'expire|pending.*24h|expirePayment' src/application/payment/payment-reconciliation.job.spec.ts
grep -nE '정합|skip|no.?op' src/application/payment/payment-reconciliation.job.spec.ts
npm test -- payment-reconciliation 2>&1 | tail -30
```

**기대 raw 출력**:
- 4 시나리오 각각 it 블록 ≥1건 (총 4건 이상)
- spec PASS, 회귀 0건
- 각 시나리오에서:
  - S1: `mockPaymentRepo.completePaymentAtomically` 1회 호출 박제
  - S2: `logger.warn` 또는 `auditLog.log` (`reconciliation_refund_mismatch`) 호출, completePaymentAtomically 0회
  - S3: `mockPaymentRepo.expirePayment` 1회 호출 박제
  - S4: 위 3 mock 모두 0회 (skip)

### AC-4: AuditLog 박제 — boost/refund mismatch/expiry 모두 operator='system_reconciliation' + reason 박제

**검증 명령**:
```bash
cd /Users/sokol/Git/ProjectGrimoire/grimoire-server
grep -nE "system_reconciliation" src/application/payment/payment-reconciliation.job.ts
grep -nE 'reconciliation_boost|reconciliation_refund_mismatch|reconciliation_expire' src/application/payment/payment-reconciliation.job.ts
grep -nE "system_reconciliation" src/application/payment/payment-reconciliation.job.spec.ts
```

**기대 raw 출력**:
- job ts 파일에 `'system_reconciliation'` 또는 `"system_reconciliation"` 1건 이상
- 3 action 식별자 (`reconciliation_boost`, `reconciliation_refund_mismatch`, `reconciliation_expire`) 박제
- spec에서 `mockAuditLogService.log` 호출 시 `operator: 'system_reconciliation'` 검증

### AC-5: 동시 cron 실행 차단 (이전 run lock check) jest spec

**검증 명령**:
```bash
cd /Users/sokol/Git/ProjectGrimoire/grimoire-server
grep -nE 'isRunning|locked|lockCheck|이미.*실행' src/application/payment/payment-reconciliation.job.ts
grep -nE 'concurrent|동시.*실행|이미.*진행|이미.*실행' src/application/payment/payment-reconciliation.job.spec.ts
```

**기대 raw 출력**:
- job ts에 `isRunning` 또는 동등 boolean lock 박제 + `try-finally`로 lock 해제 보장
- spec에 동시 실행 시나리오 it 블록 ≥1건 — 첫 호출 진행 중 두 번째 호출 시 즉시 return (counter 증가 0)
- spec에서 `expect(mockPolarAdapter.listRecentCheckouts).toHaveBeenCalledTimes(1)` 박제 (두 번째 호출은 lock 차단)

### AC-6: regression-53 + sensor-payment-reconciliation.sh 신설 + eval 52→53 PASS

**검증 명령**:
```bash
cat /Users/sokol/Git/ProjectGrimoire/eval/tasks/regression-53-payment-reconciliation.json
ls /Users/sokol/Git/ProjectGrimoire/eval/tasks/regression-*.json | wc -l
ls -la /Users/sokol/Git/ProjectGrimoire/.claude/scripts/sensor-payment-reconciliation.sh
bash /Users/sokol/Git/ProjectGrimoire/.claude/scripts/sensor-payment-reconciliation.sh
echo "exit code: $?"
bash /Users/sokol/Git/ProjectGrimoire/eval/scripts/eval-runner.sh 2>&1 | tail -10
```

**기대 raw 출력**:
- regression-53 JSON 존재 + eval_criteria ≥6건 (AC-1~5 grep 명령 박제)
- `ls regression-*.json | wc -l` 결과 53 (현재 52)
- sensor 파일 존재 + chmod +x
- 직접 실행 시 PASS (exit 0) — 검증 항목 ≥7건:
  1. `payment-reconciliation.job.ts` 파일 존재
  2. `@Cron(` 데코레이터 박제
  3. `ReconciliationCheckpoint` Prisma 모델 박제
  4. `listRecentCheckouts` payment-gateway.port 시그니처 박제
  5. `system_reconciliation` operator 박제
  6. `isRunning` lock 박제
  7. spec 파일 존재 + 4 시나리오 박제
- eval-runner stdout 마지막 행: `regression: 53/53 PASS (100%)` 또는 동등

### AC-7: cost-accountant 권고 cron 주기 적용 (cost 보고서 §3 결과 기반)

**검증 명령**:
```bash
cd /Users/sokol/Git/ProjectGrimoire/grimoire-server
grep -nE "@Cron\('[^']+'\)" src/application/payment/payment-reconciliation.job.ts
grep -E 'COST_AUDIT.*reconciliation|cron.*주기|Polar.*rate.*limit' /Users/sokol/Git/ProjectGrimoire/reports/COST_AUDIT_REPORT.md 2>/dev/null
grep -E '§3-5|cron 주기' /Users/sokol/Git/ProjectGrimoire/reports/sprint-pay-p0-2-payment-reconciliation-cron-progress.md
```

**기대 raw 출력 (cost-accountant 보고서 도착 시)**:
- cron expression이 본 progress.md §3-5에서 확정한 값과 일치 (기본 `'0 */10 * * * *'` 또는 변경 시 그 값)
- COST_AUDIT_REPORT.md에 `cron 주기 권고` 섹션 박제 + 본 sprint progress.md §3-5 라인이 cost 보고서 결정과 정합
- 사유: "Polar API rate limit X req/min 박제 → 안전 마진 N배 → 주기 Y분 권고"

**cost-accountant 미완료 시**:
- 본 AC는 **HANDOFF 대기** 표기. Generator는 임시 기본값(`'0 */10 * * * *'`)으로 진행 + DEV_REPORT.md에 "cost-accountant 보고 수신 후 본 AC 재검증 필요" 박제.
- qa는 cost-accountant 보고가 도착한 시점 이후로 본 AC를 채점 (그 전에는 SKIP 마크 박제 — qa AC-7 = N/A로 표기).

---

## 5. Test Plan

### 5-1. 단위 테스트 (jest)

| spec 파일 | 신규 it 블록 |
|---|---|
| `payment-reconciliation.job.spec.ts` (신설) | (a) S1 PG=succeeded + DB=pending → completePaymentAtomically 1회 (b) S2 PG=refunded + DB=completed → logger.warn + AuditLog `refund_mismatch` (c) S3 PG=NotFound + DB=pending (24h 경과) → expirePayment 1회 (d) S4 정합 → 모든 mock 0회 (e) 동시 실행 시 두 번째 호출 lock 차단 (f) 예외 발생 시 lock 해제 + checkpoint errorMessage 박제 (g) checkpoint lastRunAt 갱신 (h) 빈 list 응답 시 안전 종료 |
| `prisma-reconciliation-checkpoint.repository.spec.ts` (신설) | findSingleton (default seed) + update (upsert) |
| `polar.adapter.spec.ts` (확장) | listRecentCheckouts since/limit/페이지네이션 검증 |

### 5-2. 통합 테스트 — 수동 (localhost)

`reports/sprint-pay-p0-2-payment-reconciliation-cron-progress.md` Generator 단계에서:
1. localhost server 부팅 + Polar sandbox 또는 Polar mock fixture 준비
2. DB seed: pending Payment 3건 (그 중 1건은 25h 전 createdAt — expiry 대상)
3. cron 1회 수동 트리거 (e.g., `await job.run()` 또는 dev endpoint 임시 노출 후 즉시 제거)
4. 확인:
   - boost: pending → completed (status 변경 + Author.credits +N + CreditLog 생성 + AdminAuditLog `reconciliation_boost`)
   - expire: 25h 전 pending → expired (status 변경 + AdminAuditLog `reconciliation_expire`)
   - 정합 row: 변경 0건
   - checkpoint lastRunAt 갱신

**raw 박제 위치**: DEV_REPORT.md Server 섹션 §3 구현 결과 + §5 sensor 결과 (psql SELECT 결과 전문)

### 5-3. sensor 회귀

- `sensor-credit-atomicity` PASS 유지 (FAIL 회귀 시 즉시 차단 — completePaymentAtomically $transaction 패턴 유지)
- `sensor-payment-idempotency` (PAY-P0-1) PASS 유지
- `sensor-payment-reconciliation` (신설) PASS
- `sensor-shared-contracts` drift 0 (§12 신설로 mtime 갱신)
- `sensor-server` PASS (npm test + tsc 0 errors)
- `sensor-docs-sync` PASS (data-model.md + SCHEMA.md + MIGRATION.md 같은 commit)
- `sensor-adversarial-pre-commit` PASS

### 5-4. eval 회귀

- regression-52 (PAY-P0-1) PASS 유지
- regression-53 (본 Sprint 신설) PASS
- regression 52→53 / EDD 21~33 모두 PASS (drift 0)

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
| G6-1 | @nestjs/schedule 의존성 | `grep '"@nestjs/schedule"' package.json` | 1건 박제 |

### 6-2. claude-docs 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G7 | sensor 6종 | `for s in sensor-shared-contracts sensor-server sensor-docs-sync sensor-credit-atomicity sensor-payment-idempotency sensor-payment-reconciliation sensor-adversarial-pre-commit; do bash .claude/scripts/$s.sh; done` | 모두 exit 0 (PASS) |
| G8 | eval | `bash eval/scripts/eval-runner.sh` | regression 53/53 PASS, drift 0 |

### 6-3. Evaluator (qa) 채점 항목

- AC 7건 각각 PASS/FAIL 판정 (raw stdout 박제)
- AC-7은 cost-accountant 보고 도착 후만 채점 (그 전에는 N/A 마크)
- DEV_REPORT.md `Server 섹션 §5 센서 결과` raw stdout 전문 박제 여부
- QA_REPORT.md `### sprint-pay-p0-2-payment-reconciliation-cron 통과율` 박제 (목표 7/7 = 100% — AC-7 N/A 시 6/6 + 1 N/A)
- dev 환경 배포 후 cron 1회 동작 검증 (Container Apps 로그에서 `[PaymentReconciliationJob]` 로그 박제)

---

## 7. 산출물 체크리스트

### 7-1. server 산출물

- [x] `prisma/schema.prisma` — ReconciliationCheckpoint 모델 추가 (2026-05-03 server Generator)
- [x] `prisma/migrations/20260503150000_add_reconciliation_checkpoint/migration.sql` — 신설 (CREATE TABLE + INSERT singleton seed, ON CONFLICT DO NOTHING)
- [x] `src/domain/port/outbound/payment-gateway.port.ts` — NormalizedCheckout 타입 + listRecentCheckouts 시그니처 추가
- [x] `src/domain/port/outbound/payment-repository.port.ts` — findPendingPaymentsOlderThan + expirePayment 추가
- [x] `src/domain/port/outbound/reconciliation-checkpoint-repository.port.ts` — 신설 (findSingleton + update)
- [x] `src/adapter/outbound/persistence/prisma-reconciliation-checkpoint.repository.ts` — 신설 (singleton upsert + default seed fallback)
- [x] `src/adapter/outbound/persistence/prisma-reconciliation-checkpoint.repository.spec.ts` — 신설 5 it (findSingleton 정상/seed, update upsert/errorMessage/null 초기화)
- [x] `src/adapter/outbound/persistence/prisma-payment.repository.ts` — findPendingPaymentsOlderThan + expirePayment 구현
- [x] `src/adapter/outbound/payment/polar.adapter.ts` — listRecentCheckouts + mapCheckoutStatus 헬퍼 추가 (page+limit+sorting=-created_at, since clientSide 필터)
- [x] `src/adapter/outbound/payment/polar.adapter.spec.ts` — listRecentCheckouts describe 7 it 신설
- [x] `src/application/payment/payment-reconciliation.job.ts` — 신설 (`@Injectable` + `@Cron('0 */10 * * * *')` + 4 시나리오 + isRunning lock + try-finally + RECONCILIATION_DISABLED 게이트 + 3 action AuditLog)
- [x] `src/application/payment/payment-reconciliation.job.spec.ts` — 신설 9 it 블록 (S1/S2/S3/S4 + 동시실행 lock + 예외 errorMessage + checkpoint lastRunAt + 빈 응답 + RECONCILIATION_DISABLED)
- [x] `src/app.module.ts` — `ScheduleModule.forRoot()` import + PaymentReconciliationJob providers + ReconciliationCheckpointRepositoryPort DI 바인딩
- [x] `package.json` — `@nestjs/schedule@^6.1.3` 추가
- [x] `docs/api-contract.md` — Payment Reconciliation Cron 섹션 박제 (HTTP 미노출 + 동작 명세 + AuditLog operator/action)
- [x] `docs/data-model.md` — reconciliation_checkpoints 테이블 + 마이그레이션 seed 박제
- [x] `SCHEMA.md` — ReconciliationCheckpoint Prisma 매핑 + singleton 정책 + 관계 다이어그램 추가
- [x] `MIGRATION.md §7-Z` — 본 마이그레이션 절차 + INSERT singleton seed + 롤백 정책 박제
- [x] `TECH_STATUS.md` — PAY-P0-2 완료 박제 (한 줄 추가)
- [x] `INFRASTRUCTURE.md §7-A` — Container Apps cron 모니터링 안내 + 비활성화 절차 (`RECONCILIATION_DISABLED=1` env) + replicas 정책
- [x] `CHANGELOG.md` — v0.32.0 박제 (Added/Changed/Tests/Docs/Rationale + DB 마이그레이션 절)
- [x] DEV_REPORT.md Server 섹션 — raw stdout 전문 박제 (sensor PASS 10/10 + eval regression-53 9/9 + tsc 0 errors + npm test 532/532 + build PASS + prisma migrate status + psql \d + SELECT * 결과)

### 7-2. claude-docs 산출물

- [ ] `.claude/scripts/sensor-payment-reconciliation.sh` — 신설 (chmod +x, 검증 항목 ≥7건)
- [ ] `.claude/shared-contracts.md` §12 — PaymentReconciliation 인터페이스 신설 (PaymentGatewayPort.listRecentCheckouts + ReconciliationCheckpointRepositoryPort + AuditLog operator='system_reconciliation' 정책)
- [ ] `eval/tasks/regression-53-payment-reconciliation.json` — 신설 (eval_criteria ≥6건)
- [ ] PLANNING_GRIMOIRE.md — PAY-P0-2 완료 마크 (사용자 승인 필요 — Initializer는 권고만)

### 7-3. server 외 변경 없음 (web)

- 본 Sprint는 100% server 백엔드 + claude-docs (sensor + eval + shared-contracts). web 화면/플로우 변경 부재. Generator는 git diff로 web 레포 touch 0건 박제 의무.

---

## 8. 위험 / 롤백 정책

### 8-1. 위험 항목

| # | 위험 | 영향 | 완화 |
|---|---|---|---|
| R1 | Polar SDK가 list API를 미지원 또는 시그니처 다름 | listRecentCheckouts 구현 불가 | Generator가 SDK 버전 확인 후 `polar.checkouts.list` 또는 `polar.orders.list` 중 가용한 API 사용. 둘 다 부재 시 raw HTTP `GET /v1/checkouts?since=...` 직접 호출 (Polar REST API 스펙 활용). |
| R2 | replicas ≥2일 때 cron 동시 실행 | 같은 checkout이 두 worker에서 동시 처리 → race | NestJS @Cron은 replicas마다 실행됨 → DB advisory lock 또는 `pg_try_advisory_lock` 활용 권고. 본 Sprint는 replicas=1 가정 (Container Apps 현재 설정). replicas ≥2 시점에는 PAY-P1로 lock 강화. |
| R3 | Polar API rate limit 초과 | 429 응답 → cron 실패 | listRecentCheckouts 페이지네이션은 100/page → 10분당 최대 N page. cost-accountant 결과로 안전 마진 검증 후 cron 주기 조정. 429 발생 시 errorMessage 박제 + 다음 cron에서 재시도. |
| R4 | checkpoint singleton 정책 위반 (id가 'singleton' 외 값으로 INSERT됨) | 다중 row 발생 시 lastRunAt 모호 | findSingleton에서 항상 id='singleton'로 upsert. 마이그레이션 SQL에서 INSERT seed 1회 박제. |
| R5 | reconciliation이 중복 webhook과 race | 같은 payment를 webhook + cron 둘 다 처리 시도 → race | webhook은 PAY-P0-1 멱등성 게이트로 중복 차단. cron이 completePaymentAtomically 호출 시 payment.status='pending' 체크 (이미 'completed'면 skip). $transaction에서 status='pending' WHERE 절 추가 권고. |
| R6 | 24h 만료 정책이 작동 시 사용자가 결제 후 24h 이상 대기한 케이스에 영향 | 정상 결제 row가 expired 처리될 위험 | expire 대상은 **PG에서도 NotFound** (PG record 없음 + DB pending) — 정상 결제는 PG record 존재하므로 영향 0. spec에서 PG=succeeded + DB=pending(24h 경과) → boost 우선 (S1) 박제. |
| R7 | sensor-payment-reconciliation 미통과 시 commit 차단 | 개발 진행 막힘 | 본 Sprint 종료 시점 PASS 보장. WIP 단계는 sensor exit 0 보장 (체크 항목 누락 시 WARN). |

### 8-2. 롤백 정책

- **schema 차원**: ReconciliationCheckpoint 추가 + 신규 컬럼 0건 (기존 테이블 변경 0건) → 무중단 OK. 롤백 시 `DROP TABLE reconciliation_checkpoints` (데이터 손실 허용 — 신규 테이블).
- **코드 차원**: cron 비활성화는 `@Cron` 데코레이터 주석 처리 또는 환경변수 `RECONCILIATION_DISABLED=1` 게이트 (Generator가 `if (process.env.RECONCILIATION_DISABLED === '1') return` 첫 줄 박제 권고).
- **down.sql**: `DROP TABLE IF EXISTS reconciliation_checkpoints;` (참고용, 수동)

### 8-3. 사전 백업 권장 (dev/prod 운영자)

```bash
# 본 Sprint는 기존 테이블 변경 0건 → 백업 의무 0
# 단 Generator가 boost/expire 동작 시 PROD payments의 status 변경 발생 → pre-deploy backup 권고
pg_dump --table=payments --data-only > backup-payments-$(date +%Y%m%d).sql
```

---

## 9. 마이그레이션 정책 (server agent 준수)

1. **명명**: `{YYYYMMDDHHMMSS}_add_reconciliation_checkpoint`
2. **up.sql**:
   ```sql
   CREATE TABLE "reconciliation_checkpoints" (
     "id" TEXT NOT NULL DEFAULT 'singleton',
     "last_run_at" TIMESTAMPTZ(3) NOT NULL,
     "processed_count" INTEGER NOT NULL DEFAULT 0,
     "boost_count" INTEGER NOT NULL DEFAULT 0,
     "mismatch_count" INTEGER NOT NULL DEFAULT 0,
     "expire_count" INTEGER NOT NULL DEFAULT 0,
     "error_message" TEXT,
     "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
     CONSTRAINT "reconciliation_checkpoints_pkey" PRIMARY KEY ("id")
   );

   -- singleton seed: 첫 cron 실행 시 사용할 lastRunAt = NOW() - 24h
   INSERT INTO "reconciliation_checkpoints" ("id", "last_run_at")
   VALUES ('singleton', CURRENT_TIMESTAMP - INTERVAL '24 hours')
   ON CONFLICT ("id") DO NOTHING;
   ```
3. **down.sql**: 미작성 (재실행 위험 0건 — 신규 테이블 추가만)
4. **schema.prisma 변경 후** `npx prisma migrate dev --name add_reconciliation_checkpoint` (Generator 실행)
5. **dev 배포 시**: `npx prisma migrate deploy` (운영자 또는 GitHub Actions)
6. **무중단 OK** — 기존 테이블 0건 변경

---

## 10. shared-contracts §12 신설 안 (claude-docs Generator 박제 정본)

claude-docs Generator는 아래 텍스트 블록을 `.claude/shared-contracts.md` `## 11. WebhookEventIdempotency` 섹션 직후에 박제 (`{HASH}` 표기는 실제 markdown 헤딩 `#` 두/세 개로 치환):

```text
{HASH}{HASH} 12. PaymentReconciliation (server 도메인 — PG↔DB 정합성 검증 cron)

**위치**:
- Job: `grimoire-server/src/application/payment/payment-reconciliation.job.ts`
- Port (gateway): `grimoire-server/src/domain/port/outbound/payment-gateway.port.ts` (listRecentCheckouts)
- Port (checkpoint): `grimoire-server/src/domain/port/outbound/reconciliation-checkpoint-repository.port.ts`
- DB 모델: `grimoire-server/prisma/schema.prisma` (ReconciliationCheckpoint singleton)

**적용**: NestJS @Cron 10분 주기 (cost-accountant 권고 기반 조정 가능). webhook 누락 자동 발견 + 자동 보정.

{HASH}{HASH}{HASH} 시그니처

(본 sprint progress §3-6/§3-7 그대로 복사 — ReconciliationCheckpointRepositoryPort + NormalizedCheckout + PaymentGatewayPort.listRecentCheckouts)

{HASH}{HASH}{HASH} 정책

- ReconciliationCheckpoint는 항상 1 row 유지 (id='singleton')
- cron 동시 실행 차단: in-memory `isRunning` lock + try-finally
- 4 시나리오: S1 boost(PG=succeeded+DB=pending) / S2 mismatch(PG=refunded+DB=completed) / S3 expire(PG=NotFound+DB=pending+24h) / S4 정합(skip)
- 모든 자동 보정 action은 AdminAuditLog에 operator='system_reconciliation' + 3 action 식별자(reconciliation_boost / reconciliation_refund_mismatch / reconciliation_expire) 박제
- replicas ≥2 시점에는 advisory_lock으로 강화 (PAY-P1)

{HASH}{HASH}{HASH} 변경 이력
- 2026-05-03 PAY-P0-2: PaymentReconciliation 인터페이스 신설 (PG↔DB 정합성 cron, CERTI_PROJ thermage-batch-api 패턴 차용 + Grimoire 10분 주기 완화)
```

추가로 shared-contracts.md 마지막 줄 `마지막 업데이트:` 라인을 `2026-05-03 (§12 PaymentReconciliation 신설)`로 교체.

---

## 11. HANDOFF Chain

```
planner (Initializer — 본 sprint progress + PLANNER_REPORT 갱신 완료)
  ↓
cost-accountant (사전 — ⚠️ HANDOFF 대기. Polar API rate limit 조사 + cron 주기 권고. 본 progress.md §3-5 갱신 의무. 메인 또는 사용자가 SendMessage로 결과 전달.)
  ↓
visual-canon-keeper (사전 — ✅ 면제. 시각 정본 변경 0건 — 100% 백엔드 + sensor + 마이그레이션 + 정본 문서.)
  ↓
grimoire-server (Generator)
  - 본 progress.md §2 IN — server 22건 + §7-1 산출물 체크리스트 완수
  - DEV_REPORT.md Server 섹션 §5 raw stdout 전문 박제
  - 검증 게이트 G1~G6-1 모두 PASS
  ↓ (병렬 가능)
grimoire-claude-docs (Generator) — 메인 또는 planner 직접 박제
  - sensor + shared-contracts §12 + eval task 신설
  - 검증 게이트 G7 + G8 PASS
  ↓
grimoire-qa (Evaluator)
  - AC 7건 raw 채점 (PASS/FAIL/N-A 박제, AC-7은 cost-accountant 결과 도착 후 채점)
  - QA_REPORT.md `### sprint-pay-p0-2-payment-reconciliation-cron 통과율` 박제
  - dev Container Apps 로그에서 cron 1회 실행 박제
  ↓
사용자 (배포 게이트 최종 판정)
  - qa PASS 시 develop → main per-repo 머지 (server + claude-docs 2 레포)
  - prod 배포 (npx prisma migrate deploy + Container Apps 재배포)
```

- **next agent**: cost-accountant (HANDOFF 대기) → grimoire-server + grimoire-claude-docs (병렬) → grimoire-qa
- **마감**: 본 세션 종료 전 dev 머지 (사용자 명시 — "dev까지 진행 + 머지")
- **단일 진실**: 본 progress.md (Generator/Evaluator 모두 본 파일 Read 후 작업, 모호하면 본 파일 갱신 후 합의)
- **cost-accountant HANDOFF 대기 마킹**: AC-7 + §3-5 cron 주기 + §8-1 R3 (rate limit) 모두 cost-accountant 결과 수신 후 갱신 의무

---

## 12. 참조

- `research/PAYMENT_SYSTEM_PLAN.md` §3-1 PAY-P0-2 + §11 (CERTI_PROJ thermage-batch-api 인용)
- `reports/sprint-pay-p0-1-webhook-event-id-idempotency-progress.md` (선행 Sprint — 산출물 체크리스트 [x] 박제 완료)
- `grimoire-server/src/application/payment/payment.usecase.ts` (PAY-P0-1 완료 시점 — webhookEventRepo 멱등성 게이트 활용 패턴)
- `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` (Polar SDK 활용 패턴 — initiatePayment + verifyAndParseWebhook)
- `grimoire-server/src/application/admin/audit-log.service.ts` (AdminAuditLog operator 추적 — 본 Sprint에서 operator='system_reconciliation' 활용)
- `grimoire-server/CLAUDE.md` §9 결제/크레딧 원자성 + §3 문서 동기화 + §5 Hexagonal 절차
- `.claude/shared-contracts.md` §11 (PAY-P0-1 신설) + §12 (본 Sprint 신설)
- 책 Ch 16 Anthropic 3-에이전트 (Initializer → Generator → Evaluator) — 묶음 II 4회차
- 책 Ch 16 충돌 2번 해결책 (shared state via DB single-row checkpoint)
- CERTI_PROJ 인용:
  - `/CERTI_PROJ/thermage-batch-api/src/modules/batch/schedules/batch.schedule.ts:17-37` — @Cron 정합성 검증
  - `/CERTI_PROJ/thermage-batch-api/src/modules/batch/services/usage-complete-bulk.service.ts:27-100` — 페이지네이션 + lock check
- Polar SDK: `@polar-sh/sdk` checkouts.list / orders.list (Generator가 SDK 버전 확인 후 사용 가능 API 박제)

---

**마지막 업데이트**: 2026-05-03 (Initializer 신설 — cost-accountant HANDOFF 대기, AC-7 + §3-5 cron 주기 결정 보류)
