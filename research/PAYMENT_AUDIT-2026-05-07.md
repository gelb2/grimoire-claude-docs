# PAYMENT_AUDIT — 결제 시스템 전수 조사 (2026-05-07)

> **계기**: 사용자 명시 (2026-05-07) — 결제 기능 고도화 + 결제 레이어 구멍·모순점 + 영수증 기록 + 서드파티 결제 실패/네트워크 끊김 추적 + dev 추가 체크 리스트.
>
> **조사 방법**: Explore subagent 위임 (메인 컨텍스트 보호) + 메인 직접 검증 + 정본 정정 (PAY-P2-1/P2-3 완료 상태 + dev API 정상 박제).
>
> **정본 위치**: 본 파일이 결제 시스템 갭 + 고도화 권장 정본. PAYMENT_SYSTEM_PLAN.md (마스터) + sprint-pay-p* progress (개별 sprint) cross-reference.

---

## §0 TL;DR — 핵심 결론 5건

1. **구조 견고함** — Hexagonal + Polar SDK + `completePaymentAtomically` $transaction으로 기본 결제 원자성 보장. Payment / CreditLog / RefundLog / AdminAuditLog / WebhookEvent / WebhookRetryQueue 6개 모델 완성.
2. **멱등성 3중 방어** — L1 WebhookEvent.eventId @unique + L2 Payment.status check + L3 WebhookRetryQueue (DLQ). 단 race condition 1건 미해소 (구멍-A).
3. **DLQ 완성** — Postgres-native (외부 의존 0). Exponential backoff (1m→5m→30m→2h→12h→24h) + MAX_RETRY 10회 + permanent_failed 박제.
4. **환불 4분기 완성** — refund_normal/deficit/partial/partial_deficit + proportionalCredits + deficitCredits 적자 추적. 단 `cancel` event만 감지 (PG `refunded` 상태 모호).
5. **운영 추적 정합** — AdminAuditLog beforeState/afterState (PAY-P2-4) + operator 5종 (system_payment / system_refund / system_reconciliation / system_cleanup / system_dlq) + dev cron 작동 직접 검증 (16:05 + 16:10).

---

## §1 결제 도메인 구멍 + 모순점 매트릭스 (6건)

| # | 발견 | 영향 | 코드 위치 | 권장 해결 | 우선순위 |
|---|------|------|----------|---------|---------|
| **구멍-A** Race condition: 동일 eventId 다른 type 처리 누락 | 결제 완료 후 빠른 환불/취소 누락 | `payment.usecase.ts:147-160` `processNormalizedWebhook` 진입 시 existing 체크 = `status='processed'`만, payment.status='completed'도 체크 필요 | existing.status `OR` payment.status='completed' 동시 체크 | P1 |
| **구멍-B** Transaction boundary: refund 시 Author.findUnique race | 동시 환불 → 잔액 중복 차감 가능 | `prisma-payment.repository.ts:144-199` $transaction 내 findUnique 후 decrement, lock 부재 | `SELECT ... FOR UPDATE` 또는 `findUniqueOrThrow + updateMany` 원자 재구성 | P1 |
| **구멍-C** Error handling 모호: Polar timeout vs network error 구분 미흡 | 일시적 timeout과 영구 실패 동일 retry | `payment.usecase.ts:206-223` catch에서 모든 exception → retry queue 박제 (timeout 정책 미명시) | Polar SDK exception type 매핑 + timeout 정책 명시 | P1 |
| **모순-D** Retry 중복: WebhookRetryJob(5분) vs PaymentReconciliationJob(10분) 커버리지 겹침 | S1 boost 후 retry job에서 same payment 재처리 가능 | `payment-reconciliation.job.ts:118-122` S1 logic vs `webhook-retry.job.ts:82` `processNormalizedWebhook` | retry job 진입 시 payment.status='completed' 체크 추가 (boost됐으면 skip) | P1 |
| **모순-E** Status enum 불일치: Payment 7가지 vs WebhookEvent 3가지 | 상태 추적 일관성 약함 | `schema.prisma:199, 218` Payment(pending/completed/failed/refunded/partial_refunded/expired) vs WebhookEvent(processed/skipped/failed) | WebhookEvent에 `permanent_failed` 추가 + mapping table 박제 | P2 |
| **모순-F** FK cascade 미정의: Author 삭제 시 Payment/CreditLog 고아 | 데이터 정합성 + EMAIL-P0-2 SQL 백필에서 발견 (works.author_id_fkey 위반) | `schema.prisma:11-29` Author model `onDelete` directive 부재 | `onDelete: Cascade` 또는 `Restrict` 선택 + 문서화 | P1 |

### 추가 발견 (cron 정책 정합)
- `payment-cleanup.job.ts:45` cron `'0 0 4 * * *'` (한국 시간대 가정 hardcode)
- `payment-reconciliation.job.ts:59` cron `'0 */10 * * * *'` (10분 주기, dev 작동 직접 검증 16:10)
- `webhook-retry.job.ts:55` cron `'0 */5 * * * *'` (5분 주기, dev 작동 직접 검증 16:05/16:10)

---

## §2 영수증 기록 정합 + 갭

### 모델 인벤토리 (실측 — `prisma/schema.prisma`)

| 모델 | 목적 | 평가 | 갭 |
|------|------|------|------|
| `Payment` (L192-203) | 결제 주 기록 | ✅ 기본 | ❌ `refundedAt` / `partialRefundAt` 미정의 — 환불 시점 추적 불가 |
| `CreditLog` (L97-105) | 크레딧 변동 로그 | ✅ amount(±) + reason + createdAt | — |
| `RefundLog` | 환불 상세 (proportionalCredits + deficitCredits) | ✅ source('webhook'\|'manual') 구분 | ⚠️ refundedAt vs processedAt 중복 (processedAt만 사용) |
| `AdminAuditLog` | 운영자 행위 감사 | ✅ operator + action + beforeState/afterState (PAY-P2-4) | — |
| `WebhookEvent` (L212-223) | 멱등성 + 디버깅 | ✅ eventId @unique + payload JSON | — |
| `WebhookRetryQueue` | DLQ 큐 | ✅ nextRetryAt + retryCount + lastError | — |

### 갭 4건

1. **영수증 PDF 자동 생성 미구현** — Polar dashboard 외부 URL만 (사용자 노출 필요, EMAIL-P1-3 결합)
2. **세금계산서** — Polar MoR이지만 한국 KYC 후 사업자 등록 필요 (구독제 도입 시 필수)
3. **환율 기록 부재** — `Payment.amount` KRW 고정, 다국 결제 시 환율 스냅샷 필요
4. **부분 환불 시점 미추적** — `Payment.refundedAt` / `Payment.partialRefundAt` 컬럼 없음 → CreditLog reason='refund_partial_X' 문자열 파싱만

---

## §3 서드파티 결제 실패 + 네트워크 끊김 추적

### Polar SDK 호출 실패 처리

```typescript
// payment.usecase.ts:106
const result = await this.paymentGateway.initiatePayment({...})
```

| 영역 | 현황 | 평가 |
|---|---|---|
| `paymentGateway.verifyAndParseWebhook` 시그니처 검증 | ✅ 구현 | — |
| `findByExternalTransactionId` 불명 webhook 처리 | ✅ 구현 (L162-173) | — |
| Polar SDK timeout 명시 정책 | ❌ **미명시** (기본값 의존) | P1 권장 |

### DLQ 완성도

| 구성요소 | 현황 | 평가 |
|---|---|---|
| WebhookRetryQueue 테이블 | ✅ Postgres native | 외부 인프라 의존 0 |
| Exponential backoff | ✅ `calculateNextRetryAt` (L130-139): 1m→5m→30m→2h→12h→24h | 권장 정책 정합 |
| MAX_RETRY 10회 | ✅ hardcode (L39) | permanent_failed 박제 (AuditLog `system_dlq`) |
| Permanent fail 조건 | ✅ `newCount ≥ 10 → deleteById + markPermanentFailed` | webhook_events status='failed' 박제 |
| 운영자 알림 (Sentry/APM) | ❌ **미연결** | P1 권장 |
| Retention 정책 | ❌ 미정의 | 90일 권고 (PAY-P2-5 신설 권장) |

### Polar webhook 재전송

- Polar 자체 재전송 정책 (지수 백오프) 명시 안 됨
- ProjectGrimoire DLQ (5분 주기)는 Polar 재전송과 독립적 → **이중 방어 정합**

### Production 환경 검증 (정정 박제)

> **메인 정정 (Explore 보고 outdated 정정)**: 본 세션 직접 검증 결과 **dev API revision 157 Healthy 정합** (Explore가 HANDOVER §1.4의 `revision 152/153 Unhealthy` 인용했으나 그 후 `156 Healthy → 157 Healthy` 신설). PAY-P2-2 + PAY-P0-2 cron dev 실 작동 직접 검증 박제 (16:05/16:10).

---

## §4 결제 기능 고도화 권장 (10건)

### P0 우선순위 (즉시 착수)

1. **영수증 PDF 자동 생성** — HTML→PDF 라이브러리 (puppeteer 또는 react-pdf) + 사용자 이메일 발송 (EMAIL-P1-3 결합)
2. **운영자 결제 현황 대시보드** — 실시간 모니터링 (Payment status pie / Revenue MTD / Failed payment list)
3. **PG `refunded` 상태 자동 환수** — 현재 `cancel` event만 감지 (refund-payment.usecase 진입 보강)

### P1 우선순위 (한 주 이내)

4. **Sentry/APM 통합** — 결제 실패 자동 알림 (Polar 5xx, webhook timeout, DB 예외)
5. **사용자 결제 알림 (이메일/SMS)** — success/failure/refund 템플릿 (EMAIL-P1-3 + PAY-P3 결합)
6. **Circuit breaker 패턴** — Polar API 연속 5xx 시 결제 routes 임시 차단 + graceful degradation
7. **§1 구멍 A/B/C/D 해소 sprint** — race condition + transaction lock + Polar timeout 정책 + retry 중복

### P2 우선순위 (구독제 도입 시)

8. **Bull/BullMQ 도입** — replicas≥2 시점에 in-memory `isRunning` → advisoryLock 전환
9. **결제 A/B 테스트** — variant별 conversion (Polar checkout.success_url 쿼리 파라미터)
10. **KYC 게이트** — Polar KYC 미완료 시 결제 routes 차단 메시지 (사업자 구성 후)
11. **Webhook 비동기화** — webhook controller 200 즉시 + 별도 큐 위임 (timeout 회피)

### PAY-P2-5 신설 권장 (audit retention)

- 90일/180일/영구 정책 결정
- AdminAuditLog 양 폭증 시 인덱스 전략 + 파티셔닝

---

## §5 dev 추가 체크 리스트

### A. 메인 자율 가능 영역 (가드 통과)

| # | 체크 | 명령 | 기대 |
|---|------|------|------|
| 1 | WebhookRetryJob @Cron 5분 자연 발동 | logs `[WebhookRetryJob]` grep | ✅ 16:05 + 16:10 박제 (본 세션 직접 검증) |
| 2 | PaymentReconciliationJob @Cron 10분 자연 발동 | logs `[PaymentReconciliationJob]` grep | ✅ 16:10 since=15:20 processed=0 (본 세션 직접 검증) |
| 3 | PaymentCleanupJob @Cron 새벽 4시 (KST 4시 = UTC 19시) | logs `[PaymentCleanupJob]` grep | ⏳ 시간대 외, 다음 세션 또는 ScheduleWakeup |
| 4 | prisma migrate status (firewall 임시) | `az postgres flexible-server firewall-rule create` + `prisma migrate status` | ✅ 29 migrations applied + schema up to date (본 세션 직접 검증) |
| 5 | DB row count (Payment / WebhookEvent / RefundLog / AdminAuditLog) | `psql -c "SELECT ..."` | dev 운영 row 수 박제 |
| 6 | DLQ row 추적 | `SELECT * FROM webhook_retry_queues WHERE retry_count > 0` | 0건 또는 의도된 retry 박제 |
| 7 | AuditLog 최근 행위 (operator별) | `SELECT operator, COUNT(*) FROM admin_audit_logs GROUP BY operator` | system_payment / system_refund / ... 분포 |

### B. 사용자 명시 권한 영역

| # | 체크 | 준비 | 명시 키워드 |
|---|------|------|------|
| 1 | POST /payments/webhook valid signature mock | Polar dashboard 또는 HMAC 생성 | `Polar webhook 시뮬 진행` |
| 2 | 정상 200 로그인 (browser 자격증명) | Safari + dev API 정상 (✅ 본 세션 검증) | 사파리 직접 |
| 3 | prod 영역 변경 (보안 마이그레이션 + EMAIL-P0-2 + main 머지) | dev 24h 안정성 | `prod 보안 마이그레이션 진행` / `prod EMAIL-P0-2 백필 진행` / `server main 머지 진행` |
| 4 | DLQ retry 의도적 시뮬 (webhook fail) | 테스트 결제 + exception throw | `DLQ 의도 시뮬 진행` |
| 5 | Audit log retention 정책 결정 | 90일/180일/영구 | `audit retention 90일 진행` (또는 다른 정책) |
| 6 | PaymentCleanupJob 작동 직접 검증 | UTC 19시 (KST 4시) logs | 자동 시간대 도달 후 logs 자동 검증 |

---

## §6 우선순위 매트릭스 (PAY-P0/P1/P2 정합)

### 완료 (다른 세션 #10_8 + 본 세션 종료)

| Sprint | 완료 일자 | 핵심 산출물 |
|---|---|---|
| PAY-P0-1 webhook event_id 멱등성 | 2026-05-03 | WebhookEvent + L1/L2/L3 3중 방어 |
| PAY-P0-2 PG↔DB 정합성 cron 10분 | 2026-05-03 | PaymentReconciliationJob + dev 작동 직접 검증 ✅ |
| PAY-P0-3 운영자 수동 크레딧 UI | 2026-05-03 | admin/credits/grant + audit |
| PAY-P1-1 Refund 4분기 처리 | 2026-05-03 | refund_normal/deficit/partial/partial_deficit |
| PAY-P1-3 결제 실패 retry + cleanup cron | 2026-05-04 | 24h pending 재사용 + payment-cleanup.job 새벽 4시 |
| PAY-P2-1 부분 환불 비율 + 4 action | 2026-05-05 (다른 세션) | proportionalCredits 계산 |
| PAY-P2-2 Webhook DLQ + WebhookRetryJob | 2026-05-05 (다른 세션) | webhook_retry_queues + 5분 cron + dev 작동 직접 검증 ✅ |
| PAY-P2-3 SmsServicePort 캡슐화 | 2026-05-05 (다른 세션) | SMS Hexagonal Port + NullSmsAdapter |
| PAY-P2-4 AdminAuditLog 정밀화 | 2026-05-07 (본 세션) | beforeState/afterState 6-arg BACKWARD COMPATIBLE |

### 진행 권장 (P0~P2)

| Sprint | 우선순위 | 예상 시간 | 외부 API |
|---|---|---|---|
| **PAY-P2-5 audit retention 정책** | P0 | ~3h | 0 (cleanup cron만) |
| **PAY-P3-A Race condition 해소** (구멍 A/B) | P1 | ~5h | 0 |
| **PAY-P3-B Polar SDK timeout 정책** (구멍 C) | P1 | ~2h | 0 |
| **PAY-P3-C retry 중복 해소** (모순 D) | P1 | ~2h | 0 |
| **PAY-P3-D Status enum 정합** (모순 E) | P2 | ~2h | 0 |
| **PAY-P3-E FK cascade 정책** (모순 F) | P1 | ~3h | 0 (DB schema 변경 + 마이그레이션) |
| **PAY-P3-F 영수증 PDF + 이메일** | P0 | ~16h | EMAIL-P1-3 + puppeteer |
| **PAY-P3-G Sentry/APM 통합** | P1 | ~8h | Sentry SaaS (cost-accountant 마진) |
| **PAY-P3-H Circuit breaker** | P1 | ~4h | 0 |

---

## §7 변경 이력

- 2026-05-07 본 파일 신설. Explore subagent 위임 결과 + 메인 정정 (PAY-P2-1/P2-3 완료 상태 + dev API revision 157 Healthy 정합) + dev 체크 리스트 메인/사용자 영역 분리.

---

## §8 참조 (file:line)

### 정본 문서
- `research/PAYMENT_SYSTEM_PLAN.md` — PAY 마스터 플랜 (2026-05-03)
- `.claude/shared-contracts.md` §11~§20 — 결제 인터페이스 규약
- `HANDOVER_NEXT_SESSION.md` §1.5 — dev 체크 + 사용자 영역
- `reports/HANDOVER-CRITICAL-2026-05-06-PP.md` §9 Quick Start

### 핵심 코드 (server)
- `application/payment/payment.usecase.ts:106-113, 147-160, 162-173, 206-223`
- `application/payment/refund-payment.usecase.ts:75-170`
- `application/payment/payment-cleanup.job.ts:45`
- `application/payment/payment-reconciliation.job.ts:59, 118-122`
- `application/payment/webhook-retry.job.ts:39, 55, 82, 130-139`
- `application/admin/audit-log.service.ts:22-49` (PAY-P2-4 시그니처)
- `adapter/outbound/persistence/prisma-payment.repository.ts:144-199`
- `prisma/schema.prisma:11-29 (Author), 97-105 (CreditLog), 192-203 (Payment), 212-223 (WebhookEvent)`

### Sprint progress
- `reports/sprint-pay-p0-1/2/3-progress.md`
- `reports/sprint-pay-p1-1/3-*.md`
- `reports/sprint-pay-p2-1/2/3/4-*.md`

### 관련 이슈
- EMAIL-P0-2 dev SQL 백필 (본 세션 완료, UPDATE 전략 FK 회피)
- EMAIL-P1-3 결제 영수증 이메일 (외부 API 결정 후)
- 작업 A 구독제 요금제 (Polar Subscription + KYC)

---

**조사자**: Explore subagent + 메인 정정 검증 (2026-05-07)
**상태**: research/ 정본 박제 완료. 메인 자율 영역 + 사용자 명시 영역 분리. PAY-P3 sprint 후보 9건 도출.
