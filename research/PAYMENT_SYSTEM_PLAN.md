# PAYMENT_SYSTEM_PLAN — Grimoire 결제 시스템 정밀 진단 + 단계별 구현 계획

> **작성**: 2026-05-03 #10_7 세션 자율 박제
> **트리거**: 사용자 요청 — "Polar 결제 쓰지만 영수증 검증 / DB 기록 / 운영자 페이지 보완 등 신경 쓸 게 많다. 정밀 진단 후 진행"
> **분석 대상**: CERTI_PROJ 15개 프로젝트(웹/서버, ios/android 제외) + Grimoire 현재 payment 모듈 정밀 비교
> **분석 방식**: 3 Explore subagent 병렬(admin / customer-web / backend) + 메인 직접(no1-sass paymentService + brightmall-v2 checkout + Grimoire 코드)
> **상태**: 분석 + 계획 박제 완료. 구현 착수는 사용자 명시 후 (작업 D/E/A 핸드오버 시퀀스와의 우선순위 결정 영역)

---

## 0. TL;DR — 핵심 결론

Grimoire 결제 시스템은 **Hexagonal + Polar SDK + completePaymentAtomically 트랜잭션 + AdminAuditLog**로 기본 골격은 단단합니다. 그러나 운영 안정성·환불 정밀·정합성 검증·영수증 발급 측면에 **10건의 갭**이 있습니다.

Polar는 MoR(Merchant of Record)이므로 영수증/세금계산서/VAT 처리는 Polar가 담당하지만, **수동 지급 / 환불 처리 / Webhook 누락 보완 / 정합성 검증 / 알림** 등은 우리 책임입니다.

**우선순위 (사용자 결정 영역)**:
- **P0**: Webhook event_id 멱등성 테이블 + PG↔DB 정합성 검증 batch + 운영자 수동 지급 web UI
- **P1**: Refund 정밀 처리 + 결제 알림 + 결제 실패 retry 정책
- **P2**: Polar Subscription 도입 (작업 A 구독제 요금제와 결합) + 부분 환불

---

## 1. Grimoire 현재 결제 시스템 정밀 인벤토리

### 1-1. 코드 인벤토리 (실측)

| 레이어 | 파일 |
|------|------|
| Domain Port | `domain/port/outbound/payment-gateway.port.ts` (PG 추상화) |
| Domain Port | `domain/port/outbound/payment-repository.port.ts` |
| Domain Port | `domain/port/outbound/credit-repository.port.ts` |
| Domain Port | `domain/port/outbound/audit-log-repository.port.ts` (operator 추적) |
| Domain Model | `domain/model/credit.ts` |
| Application | `application/payment/payment.usecase.ts` (initiatePayment + processWebhook + getPaymentHistory) |
| Application | `application/payment/payment.usecase.spec.ts` |
| Application | `application/credit/credit.usecase.ts` (deduct + grant + getBalance + gift + getLogs) |
| Application | `application/admin/admin.usecase.ts` (grantCredits + deductCredits + auditLog 호출) |
| Application | `application/admin/audit-log.service.ts` |
| Adapter Outbound | `adapter/outbound/payment/polar.adapter.ts` (Polar SDK Checkout) |
| Adapter Outbound | `adapter/outbound/payment/polar-webhooks.ts` (validateEvent 캡슐화) |
| Adapter Outbound | `adapter/outbound/persistence/prisma-payment.repository.ts` (completePaymentAtomically $transaction) |
| Adapter Outbound | `adapter/outbound/persistence/prisma-credit.repository.ts` (adjustCredits + giftTransfer) |
| Adapter Outbound | `adapter/outbound/persistence/prisma-audit-log.repository.ts` |
| Controller | `adapter/inbound/http/controller/payment.controller.ts` (initiatePayment + webhook + getProducts + history) |
| Controller | `adapter/inbound/http/controller/credit.controller.ts` |
| Controller | `adapter/inbound/http/controller/admin.controller.ts` (POST /admin/credits/grant, /admin/credits/deduct, GET /admin/audit-logs) |

### 1-2. DB 모델 (실측, prisma/schema.prisma)

| 모델 | 컬럼 |
|------|------|
| `Payment` | id, authorId, productId, amount, credits, externalTransactionId(unique), status(default 'pending'), createdAt, completedAt |
| `CreditLog` | id, authorId, amount, reason, createdAt |
| `Subscription` | id, subscriberId, targetAuthorId, createdAt — **결제 무관** (작가-독자 팔로우 모델, 작업 A의 구독제 요금제는 별도 모델 신규 필요) |
| `Author.credits` | (필드) Author 모델에 credits 정수 컬럼 — adjustCredits로 increment/decrement |
| `AdminAuditLog` (실측 필요) | adminId, action, targetId, detail(JSON), createdAt — `prisma-audit-log.repository.ts:10` 참조 |

### 1-3. 결제 흐름 (실측)

```
[Client]                         [Server]                       [Polar]
  │ POST /payments/initiate                                     │
  │ ────────────────────────────▶│                              │
  │                              │ 1. PaymentRepo.create        │
  │                              │    (status='pending')         │
  │                              │ 2. polar.checkouts.create    │
  │                              │ ───────────────────────────▶ │
  │                              │ 3. updateExternalTransactionId │
  │ ◀────────── { paymentUrl }  │                              │
  │ (redirect to paymentUrl)                                    │
  │ ──────────────────────────────────────────────────────────▶ │
  │                                                  (사용자 결제) │
  │ ◀────── (returnUrl로 복귀)──────────────────────────────────│
  │ ▲ ?checkout_id 감지 → 토스트, 2초 후 refresh                  │
  │                                                              │
  │                              ◀────────────────── webhook ── │
  │                              │ 4. validateEvent (HMAC)      │
  │                              │ 5. findByExternalTransactionId │
  │                              │ 6. status === 'completed' check (멱등성 약식) │
  │                              │ 7. completePaymentAtomically │
  │                              │    $transaction:              │
  │                              │      Payment.status='completed' │
  │                              │      Author.credits += credits │
  │                              │      CreditLog.create         │
```

### 1-4. 강점 (그대로 유지)

1. ✅ **Hexagonal Architecture** — PG 교체 가능 (Polar → 다른 PG로도 PaymentGatewayPort만 교체)
2. ✅ **`$transaction` 원자성** — Payment.completePaymentAtomically(payment + credits + log 동시)
3. ✅ **HMAC Webhook 검증** — `@polar-sh/sdk/webhooks` validateEvent + WebhookVerificationError
4. ✅ **AdminAuditLog 인프라 존재** — adminId + action + targetId + detail(JSON) 추적 (admin.usecase에서 grantCredits/deductCredits 시 자동 기록)
5. ✅ **Throttle (rate limiting)** — `@Throttle({ ttl: 60000, limit: 5 })` 모든 mutation
6. ✅ **클라이언트 조작 불가** — 가격/크레딧 차감은 서버만 (URL `?checkout_id`는 토스트 표시용)
7. ✅ **약식 멱등성** — `payment.status === 'completed'` 체크 (같은 payment는 중복 처리 안 됨)
8. ✅ **Polar MoR** — 영수증/세금계산서/VAT는 Polar가 자동 발급 (한국 KYC 완료 시)

### 1-5. 갭 — 10건 (우선순위별 분류)

| # | 갭 | 영향 | 우선순위 |
|---|---|---|---|
| 1 | Webhook **event_id 기반 멱등성 테이블** 부재 (현재 payment.status 체크만) | Polar가 같은 event를 retry 시 같은 payment의 다른 event(예: succeeded → refunded) 처리 누락 가능 | **P0** |
| 2 | **PG ↔ DB 정합성 검증 batch** 부재 (Webhook 누락 발견 불가, 사용자 신고 의존) | 운영 안정성 핵심 | **P0** |
| 3 | **운영자 web UI 부재** — `/admin/credits/grant` 백엔드 API만 존재, 웹 화면 없음 | 운영자가 curl 또는 DB 직접 조작 → 사람 실수 위험 | **P0** |
| 4 | **Refund 정밀 처리 부재** — webhook에서 status='refunded' 마킹만, **크레딧 환수 트랜잭션 없음** | 환불 시 사용자가 크레딧 그대로 보유 → 적자 | **P1** |
| 5 | **결제 알림 부재** (이메일/SMS) — 결제 성공/실패/환불 시 사용자 통보 없음 | 사용자 신뢰 저하 + CS 부담 증가 | **P1** |
| 6 | **결제 실패 retry 정책 부재** — 사용자가 재시도하면 새 Payment row 생성 (orphan pending row 누적) | DB 정합성 + 정산 혼란 | **P1** |
| 7 | **Polar Subscription Product 미사용** — 일회성 결제만 지원 | **작업 A (구독제 요금제) 진입 차단** | **P1** (작업 A와 결합) |
| 8 | **부분 환불 / 부분 지급 모델 부재** — Payment.amount + credits 단일 컬럼 | 향후 부분 환불 요구 시 모델 변경 큰 마이그레이션 | **P2** |
| 9 | **DLQ (Dead Letter Queue)** 부재 — webhook 처리 실패 시 영구 손실 | 인프라 장애 / Polar 장애 / 일시적 DB 오류 시 결제 누락 | **P2** |
| 10 | **AdminAuditLog 검증 spec 부재** (실측 시 발견 — `auditLog.log()` 호출은 있지만 spec 없음) | 운영자 추적 누락 회귀 방지 약함 | **P2** |

---

## 2. CERTI_PROJ 학습 인사이트 (정밀 분석 결과)

### 2-1. 분석 대상 인벤토리

| 카테고리 | 프로젝트 | 핵심 결제 코드 |
|---|---|---|
| Admin | admin-certilife | Subscriptions/{centerflow,plasmapp,products} 18 파일 (수동 결제 승인 + 카드 관리 + 결제 이력 모달) |
| Admin | admin-hospital | ContractManagement/api.js (계약/수납 기본) |
| Admin | admin-manufacturer | SubscriptionManagement 기본 |
| Admin | no1-sass-platform | paymentService.js 70건 (TossPayments SDK 통합) |
| Customer Web | brightmall-v2 | stores/checkout.ts 116건 (MedusaJS + TossPayments + Pinia + 배송 정보) |
| Customer Web | web-app, web-customer, web-brand-center, customer-miniapp | (Explore agent 일부 권한 제약) |
| Backend | inapi | NestJS + MongoDB + Toss + Webhook controller (모두싸인/Prix) + Bull Queue |
| Backend | mq | NestJS + Bull/BullMQ + Redis (메시지큐 consumer 분리) |
| Backend | thermage-batch-api | NestJS + @Cron (10초~10분 cron) + PG↔DB 정합성 동기화 batch |

### 2-2. CERTI_PROJ 핵심 패턴 — Grimoire 적용 대상 (Top 12)

#### A. 운영자 페이지 패턴 (admin-certilife)

1. **수동 결제 승인 패턴** — `processCenterflowPayment` (centerflow/SubscriptionList.vue + inapi `subscription.centerflow.service.ts`)
   - 운영자가 특정 사용자 구독에 대해 결제 없이 paymentHistory 항목 추가 (status: COMPLETED)
   - **Grimoire 적용**: `POST /admin/credits/grant` 백엔드는 이미 있음 → web UI만 신규 (가장 핵심)

2. **결제 이력 모달 + 필터** — `PaymentHistoryModal.vue` + URL 쿼리 기반 필터
   - `?page=1&limit=10&hospitalName=xxx&status=ACTIVE&startDate=YYYY-MM-DD&endDate=YYYY-MM-DD`
   - 회차별 결제 상태(COMPLETED/PENDING/FAILED/REFUNDED) + 영수증 URL + 실패 사유 표시
   - **Grimoire 적용**: 관리자에서 사용자별 Payment 이력 조회 + 영수증 링크(Polar 자동 발급)

3. **계약 변경 이력 + 변경자 추적** — `ContractChangeHistory` (changeDate, changedBy, changeType, previousValues, newValues, reason)
   - **Grimoire 이미 일부 보유** (AdminAuditLog) — 단 before/after 값 박제는 추가 권고

4. **RBAC 다단계 분리** — `@Roles(Role.MANUFACTURER, Role.CERTILIFE, Role.HOSPITAL)`
   - super-admin / cs-admin / read-only 패턴
   - **Grimoire 적용**: 현재 단일 admin role → 향후 cs-admin/read-only 분리 권고 (P3)

#### B. 클라이언트 결제 흐름 (brightmall-v2 + no1-sass)

5. **TossPayments SDK 패턴** — `widgets.requestPayment({ orderId, orderName, successUrl, failUrl, customerEmail, customerName, customerMobilePhone })`
   - successUrl ↔ failUrl 분리 (Grimoire는 returnUrl 단일 — 실패 흐름 별도 처리 필요)
   - customerEmail/Name/Phone 전달 (영수증/세금계산서용)
   - **Grimoire 적용**: Polar Checkout에 customer info metadata 전달 (Polar가 영수증 자동 발급에 활용)

6. **MedusaJS 추상화** — PG-agnostic e-commerce 백엔드
   - **Grimoire는 이미 PaymentGatewayPort로 추상화됨** ✅ (Medusa 패턴과 동등)

7. **`useLoadingAction` (idempotency via UI state)** — pending 동안 재호출 차단 (Grimoire `useThrottle.ts:33-47`에 이미 있음)
   - **Grimoire 강점 유지**

#### C. Backend / Webhook / 배치 (inapi + mq + thermage-batch-api)

8. **Webhook 200 즉시 응답 원칙** — `@HttpCode(200)` + 처리 비동기 큐로 위임
   - 현재 Grimoire는 webhook 안에서 동기 처리 → PG가 timeout 후 retry 폭주 가능
   - **Grimoire 적용**: webhook controller는 검증 + 큐 push만, 처리는 별도 consumer

9. **Webhook event_id 멱등성 테이블** (inapi에는 없으나 권고됨)
   - `webhook_event_idempotency { event_id, service, processed_at, response }`
   - **Grimoire 적용**: P0 — Polar event_id 활용

10. **DLQ (Dead Letter Queue) + TTL** — `tracking_dead_letters` 90일 자동 삭제 (`expireAfterSeconds: 7776000`)
    - 실패 이벤트 영구 박제 → 운영자 UI에서 수동 재시도
    - **Grimoire 적용**: P2 — Polar webhook 처리 실패 시 dead_letters 테이블

11. **PG↔DB 정합성 검증 batch (가장 핵심)** — thermage-batch-api `@Cron('*/10 * * * * *')` 10초마다
    - PG API 조회 → DB 상태 비교 → 차이점 알림 + 자동 보정
    - 페이지네이션 (pageSize=100) + timeout 90s
    - **Grimoire 적용**: **P0** — Polar 주문 list API → DB Payment table 비교 → 누락 webhook 자동 보완

12. **Bull Queue + Consumer 분리** (mq 레포) — `@Processor('messageQueue') @Process(...)` 큐 타입별 분리
    - 장애 격리 (메시지 발송 실패가 결제 API 차단 안 함)
    - **Grimoire 적용**: P2 — Bull/BullMQ 도입 + Redis 인프라 추가 (또는 단순 setTimeout/cron으로 시작)

### 2-3. CERTI_PROJ 안티패턴 — Grimoire 회피 권고

| # | 안티패턴 | Grimoire 현 상태 | 회피책 |
|---|---|---|---|
| A1 | Webhook 처리 시 중복 검증 없음 | 약식 (status 체크) | event_id 멱등성 테이블 (P0) |
| A2 | 영수증/세금계산서 자체 발급 안 함 | Polar MoR (자동) — 단 KYC 후 | Polar dashboard 영수증 URL 사용자 노출 |
| A3 | 환불 트랜잭션 롤백 미흡 | 부재 (P1 갭) | refundPaymentAtomically $transaction 신설 |
| A4 | 운영자 권한 로그 없음 | AdminAuditLog 보유 ✅ | spec 추가 + before/after 값 박제 (P2) |
| A5 | 결제 실패 자동 재시도 부재 | 부재 | 큐 기반 재시도 (P1) |
| A6 | Webhook 응답 지연 | 가능 (동기 처리) | 200 즉시 + 큐 push (P1) |
| A7 | 동기적 PG 연동 | 가능 | 메시지 큐로 위임 (P2) |
| A8 | 트랜잭션 없는 다중 저장 | 없음 (`$transaction` 사용) ✅ | 유지 |

---

## 3. 우선순위별 구현 계획

### 3-1. P0 (운영 오픈 전 필수, ~1 sprint = 1주)

#### P0-1: Webhook event_id 멱등성 테이블

**목표**: Polar가 같은 event를 retry 시 중복 처리 절대 차단. 같은 payment의 다른 event(succeeded → refunded) 누락 차단.

**산출물**:
- DB: `WebhookEvent { eventId(@unique), source('polar'), eventType, payload(JSONB), processedAt, status('processed'|'failed'|'skipped'), errorMessage }`
- 마이그레이션: `prisma/migrations/{ts}_webhook_event_idempotency/`
- `payment.usecase.processWebhook` 변경: validateEvent 후 `webhookEventRepo.findByEventId(event.id)` → 이미 처리됨이면 즉시 200 + skip
- spec: 같은 event_id 두 번 호출 → 두 번째는 처리 안 됨 검증

**검증 게이트**:
- jest spec 추가 PASS
- eval task 신규 (regression-52-webhook-event-id-idempotency)
- sensor-credit-atomicity (기존) 회귀 PASS

**규모**: ~1.5h (구현) + ~30분 (마이그레이션 검증)

#### P0-2: PG ↔ DB 정합성 검증 Batch

**목표**: Webhook 누락 자동 발견. 운영자 신고 의존 0건.

**산출물**:
- `application/payment/payment-reconciliation.job.ts` (NestJS @Cron('0 */10 * * * *') — 10분마다)
- Polar SDK `polar.checkouts.list({ since: lastRunAt })` → DB Payment.externalTransactionId 매칭
- 차이점 (PG에는 succeeded인데 DB에는 pending): 자동 boost (completePaymentAtomically 호출) + AdminAuditLog 박제 (operator_id='system_reconciliation')
- 차이점 (DB에는 completed인데 PG에는 refunded): 알림 (운영자 수동 확인 → refundPaymentAtomically)
- 알림: 임시는 logger.warn + 향후 슬랙/이메일 (P1과 결합)
- spec: mock Polar SDK + DB 시나리오 4건 검증

**검증 게이트**:
- jest spec PASS
- eval task 신규 (regression-53-payment-reconciliation)
- 로컬 cron 1회 dry-run 검증

**규모**: ~3h (Polar SDK 활용 + cron + spec)

#### P0-3: 운영자 수동 지급 web UI

**목표**: 운영자가 curl/DB 직접 조작 없이 web에서 사용자에게 크레딧 수동 지급.

**산출물**:
- web: `src/app/admin/credits/page.tsx` 신설 (또는 기존 admin tab 확장)
- UI:
  - 사용자 검색 (이메일/슬러그/ID)
  - 현재 크레딧 잔액 표시
  - 지급 금액 + 사유(필수 입력) + 확인 모달 (멀티콘펌 — admin-certilife 패턴)
  - 결과: `POST /admin/credits/grant` 호출 → 성공 토스트 + audit log 자동 기록
- 권한: AdminGuard (이미 적용됨)
- 회귀 spec (vitest) 신설

**검증 게이트**:
- vitest spec PASS
- visual-canon-keeper 검수 (admin UI는 사슴악마 정본 외 — 단 일관성 검증)
- eval task 신규 (regression-54-admin-grant-credits-ui)

**규모**: ~2h (UI + spec + 검수)

**P0 합계**: ~7h (~1주 자투리 시간)

### 3-2. P1 (운영 안정 보강, ~2 sprint = 2주)

#### P1-1: Refund 정밀 처리 (크레딧 환수 트랜잭션)

**목표**: Polar 환불 webhook 수신 시 크레딧 자동 환수. 환수 후 잔액 음수면 0 fix + 외상 기록.

**산출물**:
- `application/payment/refund-payment.usecase.ts` 신설
- `prisma-payment.repository.ts` `refundPaymentAtomically(paymentId, refundedAmount)` $transaction (Payment.status='refunded' + Author.credits -= credits + CreditLog 기록 + RefundLog 기록)
- DB: `RefundLog { id, paymentId, amount, reason, processedAt, source('webhook'|'manual') }`
- 처리 분기:
  - 사용자 잔액 ≥ refund credits → 정상 환수
  - 사용자 잔액 < refund credits → 0 fix + RefundLog에 deficit 박제 (운영자 알림)
- spec: 두 분기 모두 검증

**검증 게이트**:
- jest spec PASS
- eval task 신규 (regression-55-refund-atomicity)
- sensor-credit-atomicity 회귀 PASS

**규모**: ~2h

#### P1-2: 결제 알림 (이메일) — EMAIL_INTEGRITY_PLAN.md EMAIL-P1-3 흡수

> **2026-05-04 갱신**: 본 P1-2는 `research/EMAIL_INTEGRITY_PLAN.md` EMAIL-P1-3 (결제 이메일 알림)으로 흡수. EMAIL-P1-1 (이메일 인증 시스템) 선행 의존성 추가 — 인증 미완 사용자에게 결제 알림을 보내면 spam/bounce 위험.

**진입 게이트**:
1. EMAIL-P1-1 이메일 인증 시스템 완료 (Author.emailVerified 박제 + EmailVerification 모델)
2. **사용자 절대 규정 0-1 (외부 Anthropic API 신규 의존 영구 보류)** 이메일 SaaS에 대해 명시적 해제 결정
3. 외부 API 결정 (Resend / SendGrid / Postmark — cost-accountant 위임 후 마진 영향 검증)

**산출물**: `EMAIL_INTEGRITY_PLAN.md §2-2 EMAIL-P1-3` 참조.

**규모**: ~16~20h (EMAIL-P1-1 + EMAIL-P1-3 통합 진입 시점)

**검증 게이트**: `EMAIL_INTEGRITY_PLAN.md §4` sensor 4종 + jest spec + eval `regression-61-payment-email-notification`.

#### P1-3: 결제 실패 retry 정책

**목표**: 사용자가 결제 실패 후 재시도 시 새 Payment row 폭주 차단. 동일 productId + 24h 이내 pending payment 재사용.

**산출물**:
- `payment.usecase.initiatePayment` 변경: 같은 (authorId, productId, status='pending', createdAt > now-24h) row 검색 → 있으면 재사용 (Polar Checkout URL 재발급), 없으면 신규 생성
- DB: 변경 없음 (기존 모델로 충분)
- spec: 24h 이내 pending 재사용 + 24h 초과 만료 처리 검증
- 만료된 pending row 정리 cron (별도 — `payment-cleanup.job.ts` @Cron('0 0 4 * * *') — 매일 새벽 4시)

**검증 게이트**:
- jest spec PASS
- eval task 신규 (regression-57-payment-retry-reuse)

**규모**: ~2h

**CERTI_PROJ 차용 결정 (2026-05-04 추가 리서치)**:
- 부적합: CERTI_PROJ retry는 매월 5일 배치 (구독제 모델). Grimoire는 일회성 결제 + 사용자 즉시 재시도 UX → 다른 구조.
- 차용: pending payment 만료 cron 패턴은 CERTI `thermage-batch-api/src/modules/batch/schedules/batch.schedule.ts:17-37` (`@Cron('*/10 * * * * *')`) 박제 패턴 정합 — 이미 PAY-P0-2 reconciliation cron과 동일 패턴.
- 미차용: CERTI는 webhook 서명 검증 미흡 (Toss 직접 인증 누락) — Grimoire는 Polar `validateEvent` 캡슐화로 우월. 본 P1-3에서 추가 보강 불필요.

#### P1-4: Polar Subscription Product 도입 (작업 A 결합)

**목표**: 작업 A (AI 채팅 + 구독제 요금제)와 결합. 기존 일회성 결제와 별개의 Polar Subscription Product 생성.

**산출물**: 작업 A의 §2-5 산출물에 흡수 (이 plan에서는 게이트만 박제):
- 기획 단계: researcher 위임 (경쟁사 구독제 비교) + cost-accountant (등급별 마진 시뮬) + planner (Sprint 계약)
- 구현 단계: Subscription / SubscriptionPlan / SubscriptionLog 모델 + Polar Subscription webhook 처리 (위 P0-1 멱등성 테이블 활용)

**규모**: 작업 A 항목 (~5~8h) — 본 plan에서 분리

**P1 합계**: ~7h (P1-1~3) + 작업 A 항목 (별도)

### 3-3. P2 (장기 안정성)

#### P2-1: 부분 환불 / 부분 지급 모델

**목표**: 향후 정책 변경 (예: AI 분석 결과가 사용자 의도와 어긋날 때 50% 환불) 대비.

**산출물**:
- DB: Payment 모델 확장 (`refundedAmount`, `refundedCredits` 컬럼 추가)
- `refundPaymentAtomically` 시그니처 확장 (부분 환불 인자)
- 마이그레이션: 기존 row는 0 default

**규모**: ~1.5h (정책 결정 후)

#### P2-2: DLQ (Dead Letter Queue)

**목표**: webhook 처리 실패 시 영구 박제 + 운영자 수동 재시도.

**산출물**:
- DB: `WebhookDeadLetter { id, eventId, source, payload, failedAt, retryCount, lastRetryAt, resolved, errorMessage }`
- `payment.usecase.processWebhook` catch 블록에서 dead_letter 박제
- 운영자 UI: `/admin/payments/dead-letters` (조회 + 수동 재시도 버튼)
- TTL: 90일 (CERTI_PROJ inapi 패턴 차용)

**규모**: ~3h

#### P2-3: AdminAuditLog 검증 spec + before/after 값 박제 강화

**목표**: 운영자 수동 개입 추적의 회귀 차단.

**산출물**:
- `audit-log.service.spec.ts` 신설 (현재 spec 부재)
- `auditLog.log` 호출 시 `beforeState` / `afterState` JSON 추가 (예: 크레딧 부여 전 잔액 / 부여 후 잔액)
- spec: grantCredits / deductCredits 호출 후 audit log에 두 값 모두 박제됨 검증

**규모**: ~1.5h

#### P2-4: 결제 SMS 알림 (KISA / Toast SMS)

**목표**: 이메일 미열람 사용자 대비.

**산출물**:
- 외부 API: Toast SMS / NHN Cloud / 알리고 등 (cost-accountant 위임)
- 인프라: KISA 발신번호 등록 (사용자 결정)

**규모**: ~3h (사용자 결정 후)

**P2 합계**: ~9h (사용자 결정 후 본격 진입)

### 3-4. P3 (장기/선택)

- RBAC 다단계 (super-admin / cs-admin / read-only)
- Bull/BullMQ + Redis 도입 (현재 NestJS @Cron으로 충분 — Bull은 결제 알림 + DLQ + reconciliation 통합 시점 도입)
- 회계 시스템 연동 (PG export → 세무사 자동 전달)

---

## 4. 권장 새 DB 모델 (요약)

```prisma
model WebhookEvent {
  id          String   @id @default(uuid())
  eventId     String   @unique @map("event_id")    // Polar event ID
  source      String                                // 'polar' (향후 다른 PG 추가 대비)
  eventType   String   @map("event_type")           // 'checkout.created', 'checkout.updated' 등
  payload     Json
  processedAt DateTime @default(now()) @map("processed_at") @db.Timestamptz(3)
  status      String   @default("processed")        // 'processed' | 'failed' | 'skipped'
  errorMessage String? @map("error_message")

  @@index([source, processedAt])
  @@map("webhook_events")
}

model RefundLog {
  id           String   @id @default(uuid())
  paymentId    String   @map("payment_id")
  amount       Int                                  // 환불 금액 (원)
  credits      Int                                  // 환수 크레딧
  deficitCredits Int    @default(0) @map("deficit_credits")  // 사용자 잔액 부족 시 외상
  reason       String
  processedAt  DateTime @default(now()) @map("processed_at") @db.Timestamptz(3)
  source       String                               // 'webhook' | 'manual'

  @@index([paymentId])
  @@map("refund_logs")
}

model WebhookDeadLetter {
  id           String    @id @default(uuid())
  eventId      String    @map("event_id")
  source       String
  payload      Json
  failedAt     DateTime  @default(now()) @map("failed_at") @db.Timestamptz(3)
  retryCount   Int       @default(0) @map("retry_count")
  lastRetryAt  DateTime? @map("last_retry_at") @db.Timestamptz(3)
  resolved     Boolean   @default(false)
  errorMessage String?   @map("error_message")

  @@index([resolved, failedAt])
  @@map("webhook_dead_letters")
  // TTL: 90일 (Prisma 직접 지원 X — Postgres pg_cron 또는 batch job)
}

// (P2) Payment 모델 확장
model Payment {
  // 기존 필드 유지 +
  refundedAmount  Int @default(0) @map("refunded_amount")
  refundedCredits Int @default(0) @map("refunded_credits")
}
```

---

## 5. 권장 새 API 엔드포인트

| Method | Path | 권한 | 우선순위 |
|---|---|---|---|
| POST | `/admin/credits/grant` | AdminGuard | **이미 존재** ✅ |
| POST | `/admin/credits/deduct` | AdminGuard | **이미 존재** ✅ |
| GET | `/admin/audit-logs` | AdminGuard | **이미 존재** ✅ |
| GET | `/admin/payments` | AdminGuard | P0 (web UI 결합) |
| GET | `/admin/payments/:authorId` | AdminGuard | P0 |
| POST | `/admin/payments/:paymentId/refund` | AdminGuard | P1 |
| GET | `/admin/payments/dead-letters` | AdminGuard | P2 |
| POST | `/admin/payments/dead-letters/:id/retry` | AdminGuard | P2 |
| POST | `/internal/payment-reconciliation/run` | InternalGuard | P0 (수동 트리거 + cron) |

---

## 6. 권장 검증 게이트 (sensor 신설)

| sensor | 검증 내용 | 우선순위 |
|---|---|---|
| `sensor-payment-idempotency.sh` (신설) | webhook_events 테이블 존재 + processWebhook이 event_id 검색 패턴 보유 | P0 |
| `sensor-payment-reconciliation.sh` (신설) | payment-reconciliation.job 존재 + @Cron 적용 | P0 |
| `sensor-credit-atomicity.sh` (기존) | $transaction 패턴 유지 (강화) | P0 |
| `sensor-refund-atomicity.sh` (신설) | refundPaymentAtomically 시그니처 + spec 존재 | P1 |
| `sensor-payment-notification.sh` (신설) | 이메일 service 존재 + payment.usecase에서 호출 | P1 |
| `sensor-admin-audit-coverage.sh` (신설) | grantCredits/deductCredits/refund 모든 admin action에 auditLog.log 호출 | P2 |

---

## 7. cost-accountant 사전 검증 필요 항목 (§0 게이트)

| 항목 | §0 영향 | 검증 |
|---|---|---|
| P0-1 webhook_events 테이블 | DB write 1회/event 추가 (PostgreSQL Burstable 영향 0) | 면제 |
| P0-2 PG↔DB reconciliation cron | Polar API list 호출 10분마다 (rate limit 검증 필요) | researcher → Polar API limit 확인 |
| P0-3 web UI | 인프라 비용 0 | 면제 |
| P1-1 Refund 트랜잭션 | DB 영향 0 | 면제 |
| **P1-2 이메일 알림** | **외부 API 비용** (Resend $20/월 / SendGrid 등) | **cost-accountant 위임 필수** — 월간 결제 건수 추정 + 외부 비용 마진 영향 |
| P2-2 DLQ | DB write 추가 (실패 시만 — 영향 미미) | 면제 |
| P2-4 SMS | KISA 발신번호 + 외부 API 비용 (건당 ₩9~22) | **cost-accountant 위임 필수** |

---

## 8. 의존성 + 일정 권고 (사용자 결정 영역)

### 8-1. 핸드오버 시퀀스와의 우선순위
- 작업 D (작품별 테마 배정 UI) — 비결제 작업, ~2h
- 작업 E (조회수 급락 조사) — 비결제 작업, ~1~2h
- 작업 A (구독제 요금제 + AI 채팅 차감) — **결제 P0/P1 결합점**

### 8-2. 권고 진행 순서

**옵션 A** (안전 — 현재 핸드오버 시퀀스 그대로):
- 작업 D → 작업 E → 작업 A (구독제 + 결제 P0/P1 통합) → 결제 P2

**옵션 B** (운영 안정 우선 — 본 plan 권장):
- **결제 P0 (3건, ~7h)** → 작업 D → 작업 E → 작업 A (구독제 + 결제 P1 통합) → 결제 P2
- 이유: 운영 오픈 전 webhook 멱등성 + 정합성 batch + 운영자 수동 지급 UI는 **사고 발생 시 복구 비용**이 매우 큼. 작업 A보다 먼저 도입 권고.

**옵션 C** (작업 A 우선 — 사용자가 구독제 우선시):
- 작업 D → 작업 E → 작업 A 시작 → 결제 P0 (작업 A의 일부로 통합) → 결제 P1/P2

### 8-3. 사용자 명시 결정 필요
1. P0 3건 즉시 진행 여부 (7h 추정)
2. P1-2 이메일 알림 외부 API 선택 (Resend / SendGrid / Postmark)
3. P1-3 결제 실패 retry 정책 (24h 재사용 vs 30분 재사용)
4. P2 진입 시점

---

## 9. 메인 자율 진행 가능 항목 (사용자 명시 없이)

본 plan 박제 후 메인이 사용자 추가 결정 없이 진행 가능한 작업:

- ❌ 신규 sensor 신설 (P0/P1 해당) — sensor 신설은 본 plan에 명시한 6건이지만, 신규 sensor 도입은 결제 코드 변경과 결합되므로 사용자 명시 후
- ✅ 본 plan 자체의 후속 갱신 (인사이트 추가, 우선순위 조정)
- ✅ Polar SDK list API 활용 가능성 사전 조사 (researcher 위임 가능)
- ❌ DB 마이그레이션 (사용자 명시 후)
- ❌ 외부 API 통합 (cost-accountant 사전 게이트)

---

## 10. 변경 이력

- 2026-05-03 #10_7: 본 plan 신설 — CERTI_PROJ 15 프로젝트 정밀 분석(3 Explore subagent + 메인 직접) + Grimoire 결제 모듈 정밀 인벤토리 + 갭 10건 + 우선순위 4단계(P0~P3) + DB 모델 + API + sensor + 일정 권고 박제
- 2026-05-03 #10_7 (1): PAY-P0-1 webhook event_id 멱등성 자율 완료 (server `8c13103`) + sensor-payment-idempotency + regression-52
- 2026-05-03 #10_7 (2): PAY-P0-2 PG↔DB 정합성 cron 자율 완료 (server `8e9e02e`) + sensor-payment-reconciliation + regression-53
- 2026-05-03 #10_7 (3): PAY-P0-3 운영자 수동 크레딧 UI 자율 완료 (web `af3f04c`) + sensor-admin-credit-ui + regression-54
- 2026-05-04 #10_7 (4): PAY-P1-1 Refund 정밀 처리 자율 완료 (server `adfcae8` / web `eb64a8b` / claude-docs `2ed585e`) — 3중 멱등성(L1 webhook event_id + L2 payment.status + L3 RefundLog index) + 잔액 부족 deficit 분기 + AuditLog operator='system_refund' + sensor-refund-atomicity + regression-55
- 2026-05-04 #10_7 (5): PAY-P1-3 진입 직전 — CERTI_PROJ 웹 프로젝트 추가 리서치 (Explore 위임). 결과: retry 정책은 구조 다름(구독제 배치 vs Grimoire 일회성), 차용 가치 낮음. 단, 결제 실패 이메일 알림 (P1-2)와 DLQ Bull/Redis 패턴 (P2-2)은 향후 차용 후보로 박제.

---

## 11. 참조 (CERTI_PROJ 핵심 파일 인용)

- `/CERTI_PROJ/admin-certilife/src/views/Subscriptions/centerflow/SubscriptionList.vue` — 수동 결제 승인 UI
- `/CERTI_PROJ/admin-certilife/src/views/Subscriptions/centerflow/PaymentHistoryModal.vue` — 결제 이력 모달
- `/CERTI_PROJ/admin-certilife/src/views/Subscriptions/centerflow/CardManagementModal.vue` — 카드 관리
- `/CERTI_PROJ/inapi/src/contracts/controller/webhook.controller.ts:24-42` — webhook 200 즉시 응답
- `/CERTI_PROJ/inapi/src/core/tracking/schemas/dead-letter.schema.ts` — DLQ 90일 TTL
- `/CERTI_PROJ/inapi/src/core/tracking/services/tracking-storage.service.ts:51-62` — 지수 백오프 (MAX_RETRIES=3)
- `/CERTI_PROJ/inapi/src/subscriptions/service/subscription.centerflow.service.ts:41-96` — 구독 생성 + 결제 이력
- `/CERTI_PROJ/thermage-batch-api/src/modules/batch/schedules/batch.schedule.ts:17-37` — @Cron('*/10 * * * * *') 정합성 검증
- `/CERTI_PROJ/thermage-batch-api/src/modules/batch/services/usage-complete-bulk.service.ts:27-100` — 페이지네이션 동기화
- `/CERTI_PROJ/no1-sass-platform/src/services/paymentService.js:13-120` — TossPayments SDK 통합
- `/CERTI_PROJ/brightmall-v2/src/stores/checkout.ts:35-100` — MedusaJS + Pinia + TossPayments

## 12. 참조 (Grimoire 현재 코드)

- `grimoire-server/src/application/payment/payment.usecase.ts` — initiatePayment + processWebhook + getPaymentHistory
- `grimoire-server/src/application/credit/credit.usecase.ts` — deduct + grant + gift + getLogs
- `grimoire-server/src/application/admin/admin.usecase.ts` — grantCredits + auditLog 호출
- `grimoire-server/src/application/admin/audit-log.service.ts` — operator 추적
- `grimoire-server/src/adapter/outbound/payment/polar.adapter.ts` — Polar SDK Checkout
- `grimoire-server/src/adapter/outbound/payment/polar-webhooks.ts` — validateEvent 캡슐화
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts:25-39` — completePaymentAtomically $transaction
- `grimoire-server/src/adapter/outbound/persistence/prisma-audit-log.repository.ts` — AdminAuditLog 박제
- `grimoire-server/src/adapter/inbound/http/controller/admin.controller.ts:382-383` — getAuditLogs API
- `grimoire-server/prisma/schema.prisma` — Payment / CreditLog / Subscription / Author.credits

---

**본 plan은 정본**: 결제 시스템 변경 시 본 문서 먼저 갱신 → 코드/테스트 반영 (책 Ch 16 shared-contracts 정신 정합).
