# PAYMENT_PIPELINE_DIAGNOSIS — 결제 파이프라인 정밀진단 (2026-05-18)

> **유형**: 순수 진단 리포트 (코드 수정 0건 — 진단 전용)
> **트리거**: 메인 명시 — "결제기능 고도화" 잔여 과제 정밀진단 → sprint 분할 재추산 입력
> **진단 방법**: 실제 파일 Read + grep + git log + prisma migrate status 실측. 추측 0건 — 미확인은 명시.
> **진단 범위**: PAY-* 시리즈 (완료분 회귀 + 잔여 4건 + 전반 위험 코드)
> **정본 참조**: `research/PAYMENT_SYSTEM_PLAN.md` / `research/PAYMENT_AUDIT-2026-05-07.md` / `.claude/shared-contracts.md` §11~§28

---

## 0. TL;DR — 핵심 결론 7건

1. **완료 PAY-P0~P3 코드 건강 — 양호**. payment.usecase / refund-payment.usecase / 4 cron / polar.adapter / circuit-breaker 모두 헥사고날 DIP 준수. 회귀 발생 코드 0건. 결제 spec 168 it (payment 디렉토리 87 + polar.adapter 51 + circuit 18 + email/sms 12).
2. **CRITICAL 1건 — 로컬 DB 마이그레이션 stale**. `prisma migrate status` 실측: 로컬 localhost:5432에 **PAY-P2-2 / P2-5 / P3-E 마이그레이션 3건 미적용**. 코드는 완료됐으나 로컬 DB가 코드보다 뒤처짐. dev/prod 상태는 Azure 방화벽으로 본 진단에서 **미확인**.
3. **PAY-P1-2 (결제 알림 이메일)** — EmailServicePort + NullEmailAdapter 완성. **잔여 = (a) 결제 트리거 연결 0건 (payment.usecase에서 sendPaymentNotification 호출 없음 — 의도된 OUT), (b) 실 SaaS 어댑터 0건, (c) app.module DI 미등록**. EMAIL-P1-1 (이메일 인증) 선행 의존.
4. **PAY-P1-3 (결제 실패 retry)** — **이미 완료됨** (server `888fe2b`). 24h pending 재사용 + payment-cleanup cron 구현·spec·shared-contracts §14 박제 완료. 직전 정본 리포트(PAYMENT_NEXT_STEPS 5/4)가 stale — "잔여"로 표기됐으나 실제 완료. **잔여 작업 0건**.
5. **PAY-P3-I (Circuit Breaker 운영자 admin UI)** — server 측 Circuit Breaker 상태 노출 HTTP 엔드포인트 **0건** (CircuitBreakerPort에 getState/getStats/forceOpen/forceClose 메서드는 존재하나 컨트롤러 미연결). admin.controller에 circuit 관련 라우트 0건. **미착수 확정**.
6. **PAY-P2 잔여** — 부분 환불/부분 지급 모델은 **PAY-P2-1로 이미 완료** (RefundLog 1:N 비율 계산). AdminAuditLog spec 강화는 **PAY-P2-4로 완료**. **진짜 잔여 = SMS 알림 실 어댑터** (NullSmsAdapter + Port는 완성, 실 SaaS 어댑터 + 트리거 + DI 미등록 — 사용자 절대 규정 0-1 해제 게이트).
7. **신규 발견 위험 5건** — backlog 외. HIGH 1 (다중 부분 환불 누적 한도 미검증) / MEDIUM 3 / LOW 1. §4 참조.

---

## 1. 완료된 PAY-P0~P3 영역 — 건강 상태 (회귀·기술부채·위험 코드)

### 1-1. git log 실측 — 완료 sprint 커밋 증거

```
e05009c merge: feature/pay-p3-d-status-enum-mapping → develop (PAY-P3-D 종료)
71db1ec merge: feature/pay-p3-h-circuit-breaker → develop (PAY-P3-H 종료)
7066cd7 feat(PAY-P2-5): audit retention 정책 (영구 보존 + 90일 PII 마스킹, 옵션 D)
7097316 merge: feature/pay-p3-e-fk-cascade-policy → develop (PAY-P3-E 단계 3+4)
eb58a3d feat(payment): PAY-P3-B Polar SDK timeout 정책 — 5분류 + 4xx 즉시 permanent_failed
36fb55c feat(payment): PAY-P3-C retry 중복 해소 — webhook-retry.job 사전 dedup 게이트
e5974a9 feat(payment): PAY-P3-A race condition 차단 — 구멍-A 사전 게이트 + 구멍-B CAS 패턴
64b6187 feat(audit): PAY-P2-4 AdminAuditLog 정밀화 — beforeState/afterState 박제
83715e3 feat(sms): PAY-P2-3 사전 작업 — SmsServicePort 캡슐화 + NullSmsAdapter
88487c3 feat(payment): PAY-P2-2 webhook DLQ — Postgres RetryQueue + @Cron 5분
709ad12 feat(payment): PAY-P2-1 부분 환불 비율 계산 — 4 action 매트릭스
888fe2b feat(payment): PAY-P1-3 결제 실패 retry 정책 + payment-cleanup cron
adfcae8 merge: PAY-P1-1 Refund 정밀 처리
8e9e02e merge: PAY-P0-2 PG↔DB 정합성 검증 cron
8c13103 merge: PAY-P0-1 webhook event_id 멱등성
```

→ **PAY-P0-1/2/3 + P1-1/3 + P2-1/2/3/4/5 + P3-A/B/C/D/E/H 전부 develop 커밋 확인**. 메인 맥락 명세("완료분")와 git log 일치.

### 1-2. 코드 건강 — 파일별 실측 판정

| 파일 | 판정 | 근거 |
|------|------|------|
| `application/payment/payment.usecase.ts` | 양호 | 헥사고날 DIP 준수 (Port만 import, PrismaService 0건). processNormalizedWebhook에 멱등성 4중 게이트 (eventId / payment.status=completed / isPaymentAlreadyRefunded / createIfAbsent race). P3-B classifyAndRouteWebhookError 분기 정합. CircuitOpenError 503 변환. |
| `application/payment/refund-payment.usecase.ts` | 양호 | DIP 준수. 4분기 action 매트릭스 (refund_normal/deficit/partial/partial_deficit). AuditLog 후행 실패 시 throw 0 (트랜잭션 비차단). beforeState/afterState 박제. |
| `application/payment/webhook-retry.job.ts` | 양호 | P3-C 사전 dedup 게이트 (FINALIZED_STATUSES) 정합. exp backoff (1m→5m→30m→2h→12h→24h). MAX_RETRY 10. isRunning lock + WEBHOOK_RETRY_DISABLED env 게이트. |
| `application/payment/payment-reconciliation.job.ts` | 양호 | 4 시나리오 (S1 boost / S2 mismatch / S3 expire / S4 정합). CircuitOpenError skip 분기. checkpoint 갱신 finally 보장. |
| `application/payment/payment-cleanup.job.ts` | 양호 | 24h pending expire. row별 실패 격리 (다른 row 계속). PAYMENT_CLEANUP_DISABLED env 게이트. |
| `adapter/outbound/payment/polar.adapter.ts` | 양호 | classifyPolarError 5분류 (timeout/network/server_5xx/client_4xx/unknown) duck typing. Circuit Breaker 3 호출점 래핑. webhook-id 헤더 누락 시 안전 거부. |
| `adapter/outbound/payment/polar-webhooks.ts` | 양호 | exports map 이중 매핑 회피 캡슐화 (`@polar-sh/sdk/webhooks`). 컨테이너 부팅 실패 회귀 차단 주석 박제. |
| `adapter/outbound/persistence/prisma-payment.repository.ts` | 양호 (주의 1건) | refundPaymentAtomically — $transaction 내부 비율 계산 + CAS 패턴 (updateMany WHERE credits>=actualDeducted, count===0 시 CAS_MISMATCH throw). **주의: §4 HIGH-1 다중 부분 환불 누적 한도 미검증**. |
| `adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.ts` | 양호 | Hystrix 3 상태 머신 (CLOSED/OPEN/HALF_OPEN). env 4 정책 (failureThreshold/cooldownMs/halfOpenTrial/resetWindowMs). AuditLog 4 action. **주의: in-memory — replicas≥2 시점 분산 상태 미지원 (설계상 명시된 OUT, §3 참조)**. |

### 1-3. 회귀·기술부채 — 발견 종합

- **회귀 (CRITICAL/HIGH) 코드 0건**. 완료 PAY 영역에서 직전 sprint를 깨는 코드 미발견.
- **기술부채 (의도된 OUT, 설계 명시)**:
  - Circuit Breaker `in-memory` — `Map<string, CircuitBreakerStats>` 기반. ADR-009 + adapter 주석에 "다중 인스턴스 시점 Redis 분산 상태 별도 sprint" 명시. 현재 Container Apps replicas=1 가정. **replicas≥2 전환 시 호출점별 상태 불일치 위험** (LOW — 현 인프라에서 미발현).
  - 4 cron 모두 `isRunning` in-memory 플래그 — replicas≥2 시 동시 실행 가능. 각 job 주석에 "advisory_lock 보강 P2 보류" 명시. **현 인프라 replicas=1에서 미발현**.
  - `payment-cleanup.job.ts` cron `'0 0 4 * * *'` — 한국시간대 가정 hardcode (PAYMENT_AUDIT-2026-05-07 §1 이미 식별).

---

## 2. 잔여 4건 — 코드 상태 + 완료 작업 + 작업량 추산

### 2-1. PAY-P1-2 결제 알림 이메일 — 부분 구현 (Port만)

**현재 코드 상태 (실측)**:
- `domain/port/outbound/email-service.port.ts` — **존재**. `EmailServicePort` 인터페이스 3 메서드 (`sendVerificationEmail` / `sendPasswordResetEmail` / `sendPaymentNotification`) + `isEnabled` + `getProviderName`. `PaymentNotificationType` = payment_success/failed/refunded.
- `adapter/outbound/email/null-email.adapter.ts` — **존재**. `NullEmailAdapter` — 실 발송 0건, logger.warn + PII 마스킹 (maskEmail/maskToken), `isEnabled()=false`. spec 5 it.
- 실 SaaS 어댑터 (ResendEmailAdapter / SesEmailAdapter 등) — **0건**.
- `payment.usecase.ts`에서 `sendPaymentNotification` 호출 — **0건** (`grep -rn sendPaymentNotification src/application/` → 0건). 결제 트리거 미연결.
- `app.module.ts`에 EmailService DI 등록 — **0건** (`grep EmailService src/app.module.ts` → 0건).

**완료에 필요한 작업**:
1. (선행 의존) EMAIL-P1-1 이메일 인증 시스템 — `research/EMAIL_INTEGRITY_PLAN.md` §2-1. Author.emailVerified + EmailVerification 모델. 인증 미완 사용자에게 결제 알림 발송 시 spam/bounce 위험.
2. (게이트) 사용자 절대 규정 0-1 (외부 API 신규 의존 보류) 해제 — 이메일 SaaS 명시 결정.
3. (cost-accountant 게이트) 외부 API 선택 (EMAIL_INTEGRITY_PLAN §348 비용 시뮬: AWS SES ~₩700/월 권장 / Resend Pro ₩28K / Postmark ₩21K). 마진 영향 검증 — COST_AUDIT_REPORT 필수.
4. 실 어댑터 구현 (SesEmailAdapter 등) + app.module DI factory (env `EMAIL_PROVIDER` 분기).
5. `payment.usecase.processWebhook` success/cancel 분기 + `refund-payment.usecase` 트랜잭션 commit 후 `sendPaymentNotification` 호출 (트랜잭션 외 후행 — AuditLog 패턴 정합).
6. 결제 이메일 템플릿 3종 (success/failed/refunded).
7. spec + sensor-payment-email-notification + eval regression-61.

**작업량 추산**: 트리거 연결 + 어댑터 단독 = ~3~4h. **단 EMAIL-P1-1 선행 (~10~12h) 포함 시 통합 ~14~16h** (EMAIL_INTEGRITY_PLAN §299와 정합). 외부 API 게이트 + cost-accountant 게이트 미해제 시 **착수 불가**.

**비고**: shared-contracts §19 + EmailServicePort 주석에 "결제 트리거 미연동 = 의도된 OUT" 명시됨. Port만 선제 박제한 의도적 부분 구현이며, 미완이 아닌 게이트 대기 상태.

### 2-2. PAY-P1-3 결제 실패 retry 정책 — 이미 완료 (잔여 0건)

**현재 코드 상태 (실측)**:
- `payment.usecase.ts:178-221` `initiatePayment` — `findReusablePendingPayment(authorId, productId, expireSince=now-24h)` 진입 게이트 구현. 적중 시 Payment row 신규 생성 SKIP, 동일 paymentId 재사용. `PENDING_REUSE_HOURS = 24` 상수.
- `prisma-payment.repository.ts:85-99` `findReusablePendingPayment` — WHERE authorId+productId+status=pending+createdAt>expireSince, ORDER BY createdAt DESC, LIMIT 1.
- `application/payment/payment-cleanup.job.ts` — 24h 초과 pending expire cron (`'0 0 4 * * *'` 매일 4시). spec 6 it.
- shared-contracts §14 PaymentRetryReuse 박제 완료.
- git: `888fe2b feat(payment): PAY-P1-3 결제 실패 retry 정책 + payment-cleanup cron`.

**`webhook_retry_queue`와의 관계**: PAY-P1-3(결제 시작 시점 pending row 재사용)과 `webhook_retry_queue`(PAY-P2-2 webhook 처리 실패 DLQ)는 **별개 도메인**. 전자는 사용자 재시도 UX(Payment row 폭주 차단), 후자는 webhook 수신 실패 재처리. 두 영역 정합 — 중복/충돌 0건.

**완료에 필요한 작업**: **0건**. 직전 정본 리포트(`PAYMENT_NEXT_STEPS.md` 2026-05-04)가 PAY-P1-3을 "다음 권고"로 표기했으나 그 후 `888fe2b`로 완료됨. PAYMENT_NEXT_STEPS는 **stale 문서**.

**작업량 추산**: N/A (완료).

### 2-3. PAY-P3-I Circuit Breaker 운영자 admin UI — 미착수 확정

**현재 코드 상태 (실측)**:
- `domain/port/outbound/circuit-breaker.port.ts` — `CircuitBreakerPort`에 `getState(key)` / `getStats(key)` / `forceOpen(key, reason)` / `forceClose(key, reason)` 메서드 **정의됨**. port 주석에 "관리자 UI 영역은 P3-I 별도 sprint 분리" 명시.
- `adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.ts` — getState/getStats/forceOpen/forceClose **구현 완료**. forceOpen/forceClose는 AuditLog `circuit_breaker.open/close` (reason=`manual_force_open/close`) 박제.
- server 측 HTTP 노출 엔드포인트 — **0건**. `grep '@(Get|Post)...circuit' admin.controller.ts` → 0건. admin.controller 라우트 목록에 circuit/breaker 관련 0건.
- web 측 UI — 본 진단 범위 외 (server 진단). server가 엔드포인트를 제공하지 않으므로 web도 데이터 소스 부재.

**완료에 필요한 작업**:
- **server 측 (이번 진단 핵심)**:
  1. admin.controller에 엔드포인트 3종 신설:
     - `GET /admin/payments/circuit-breakers` — 3 호출점(`polar:checkouts:create/list/get`) getStats 일괄 반환.
     - `POST /admin/payments/circuit-breakers/:key/open` — forceOpen (body: reason).
     - `POST /admin/payments/circuit-breakers/:key/close` — forceClose (body: reason).
  2. 신규 UseCase 또는 admin.usecase 확장 — CircuitBreakerPort 주입(현재 `'CircuitBreakerPort'` 토큰 app.module 바인딩 존재).
  3. 모든 mutation에 `@UseGuards(JwtAuthGuard, AdminGuard)` + DTO class-validator + `@Throttle`.
  4. `getStats` 반환 `CircuitBreakerStats`에 Date 필드(openedAt 등) 포함 — DTO 직렬화 검증.
  5. docs/api-contract.md 정본 갱신 + web 복사.
  6. spec (admin.controller.spec + usecase spec).
- **web 측 (별도 — web agent)**: admin 패널에 Circuit Breaker 상태 카드 (3 호출점 state/failureCount/openedAt) + 수동 open/close 버튼 (확인 모달). admin neutral-* 영역 (사슴악마 정본 외 — VCK 면제).

**작업량 추산**: server ~2~3h (엔드포인트 3 + usecase + spec + docs). web ~2~3h (상태 카드 + 버튼 + spec). **합계 ~4~6h**. 외부 의존 0건 — 자율 진행 가능.

**비고**: P3-H에서 Circuit Breaker 로직 + port 메서드(forceOpen/forceClose)는 이미 P3-I용으로 선제 완성. P3-I는 순수 HTTP 노출 + UI sprint.

### 2-4. PAY-P2 잔여 — SMS 알림만 진짜 잔여

**(a) 부분 환불/부분 지급 모델 — PAY-P2-1로 완료**:
- `prisma-payment.repository.ts:129-235` `refundPaymentAtomically` — `ratio = refundedAmount/payment.amount`, `proportionalCredits = Math.floor(credits*ratio)`, `isPartial = ratio<1.0`. status `partial_refunded` 분기.
- `RefundLog` 모델 — paymentId 1:N (unique 미부여 — 다중 부분 환불 호환). amount/credits/deficitCredits 분리.
- shared-contracts §17 PartialRefund 박제. git `709ad12`.
- **잔여**: PAYMENT_SYSTEM_PLAN §4-1이 제안한 `Payment.refundedAmount`/`refundedCredits` 컬럼은 **미적용** — RefundLog 1:N 집계 방식 채택으로 대체됨. 설계 변경이며 미완 아님. (단 §4 HIGH-1 누적 한도 검증 갭은 별개.)

**(b) AdminAuditLog spec 강화 — PAY-P2-4로 완료**:
- `audit-log.service.ts` 6-arg BACKWARD COMPATIBLE 확장 (beforeState/afterState). `audit-log.service.spec.ts` 10 it 신설.
- shared-contracts §20 박제. git `64b6187`.
- **잔여**: 0건.

**(c) SMS 알림 — 진짜 잔여 (Port만 구현)**:
- `domain/port/outbound/sms-service.port.ts` — **존재**. `SmsServicePort` (sendPaymentNotification / sendVerificationCode / isEnabled / getProviderName). `PaymentSmsType` = payment_success/failed/refunded.
- `adapter/outbound/sms/null-sms.adapter.ts` — **존재**. `NullSmsAdapter` — 실 발송 0건, logger.warn + PII 마스킹 (maskPhone/maskCode). spec 7 it.
- 실 어댑터 (KakaoBizmessageAdapter / NhnCloudAdapter / TwilioAdapter) — **0건**.
- payment.usecase 트리거 호출 — **0건**. app.module DI 등록 — **0건**. (shared-contracts §19에 "결제 트리거 미연동 = 의도된 OUT" 명시.)
- git `83715e3 feat(sms): PAY-P2-3 사전 작업`.

**완료에 필요한 작업 (SMS)**:
1. (게이트) 사용자 절대 규정 0-1 해제 — SMS provider 명시 ("SMS 진입" + KAKAO Bizmessage 추천 / NHN / Twilio 1택).
2. (cost-accountant 게이트) 건당 비용 (PAYMENT_SYSTEM_PLAN §7: KISA SMS 건당 ₩9~22) + KISA 발신번호 등록 (사용자 인프라 액션).
3. 실 어댑터 구현 + app.module DI factory (env `SMS_PROVIDER` 분기).
4. payment.usecase 트리거 — Email과 동시 통합 권장 (shared-contracts §19 처리 흐름: 결제 commit 후 EmailServicePort + SmsServicePort 동시 호출).
5. spec + sensor-sms-service-port (이미 존재 — 8 검증) 확장 + eval regression-63 (이미 존재).

**작업량 추산**: 실 어댑터 + 트리거 = ~3~4h. **게이트 미해제 시 착수 불가**. Email(§2-1)과 통합 시 트리거 코드 공유 — 동시 진행 시 합산 ~1~2h 절감.

---

## 3. 의존성 — 잔여 PAY 항목 ↔ 크레딧 개편/V Phase

> 크레딧 코어는 별도 트랙 진단 중. 본 섹션은 **결제 파이프라인 관점 종속 여부만** 식별.

| 잔여 PAY 항목 | 크레딧 개편 종속 | 근거 (실측) |
|---|---|---|
| PAY-P1-2 결제 알림 이메일 | **종속 없음** | `sendPaymentNotification` payload는 paymentId/amount/credits — 결제 도메인 자체 필드. CreditLedger/MembershipPlan 미참조. EMAIL-P1-1 (이메일 인증)에만 종속. |
| PAY-P1-3 결제 실패 retry | 완료 (N/A) | — |
| PAY-P3-I Circuit Breaker admin UI | **종속 없음** | Circuit Breaker는 Polar SDK 호출 경계 — 크레딧 회계와 무관. |
| PAY-P2 SMS 알림 | **종속 없음** | Email과 동일 — 결제 도메인 필드만. |

**단, 역방향 1건 주의 (결제 → 크레딧 개편 영향)**:
- `prisma-payment.repository.ts:25-39` `completePaymentAtomically` — 현재 `tx.author.update({ credits: { increment } })` + `tx.creditLog.create`. 크레딧 개편 I Phase의 **CreditLedger 원장**(source='charged')은 별 모델. `migrate status` 실측: `20260517_credit_overhaul_i_phase` 마이그레이션이 로컬 미적용 + TECH_STATUS §2에 "코드 구현 완료 — dev migration apply 대기" 명시.
- **V Phase(크레딧 개편 마이그레이션 apply) 진입 시점에 결제 성공 경로(`completePaymentAtomically`)가 CreditLedger row(source='charged')도 박제하도록 보강 필요할 가능성**. 현 코드는 구 `Author.credits` + `CreditLog`만 갱신. 이는 **크레딧 개편 트랙의 결정 영역** — 결제 파이프라인 진단 관점에서는 "결제 성공 시 충전 크레딧 적립 경로가 크레딧 개편 후 이중 기록/단일 기록 중 무엇인지 미정"으로 **식별만** (해소는 크레딧 트랙).
- → **잔여 PAY 4건은 크레딧 개편에 종속 0건. 단 완료분 `completePaymentAtomically`는 크레딧 개편 V Phase의 영향권** (별 트랙 결정 사항).

---

## 4. 결제 파이프라인 전반 — 신규 발견 위험/누락 (backlog 외)

> 알려진 backlog(PAYMENT_AUDIT-2026-05-07 §1 구멍 6건 등)은 P3-A~E로 해소 확인. 아래는 본 진단에서 **새로 발견**한 것.

### HIGH-1 — 다중 부분 환불 누적 한도 미검증

- **위치**: `prisma-payment.repository.ts:129-235` `refundPaymentAtomically`.
- **발견**: $transaction 내부 validation은 `refundedAmount > payment.amount` 단건만 검사 (L161). `RefundLog`는 paymentId 1:N (unique 미부여 — 부분 환불 호환 의도). 그러나 **이미 환불된 RefundLog.amount 합계를 조회·합산하는 로직이 0건**.
- **위험 시나리오**: 같은 payment(amount=10000)에 부분 환불 webhook이 두 번 도달 (각 refundedAmount=6000) → 각 호출은 6000≤10000 통과 → 총 12000 환불 + proportionalCredits 합계가 원래 credits 초과 가능 → 적자.
- **완화 요인**: (a) processNormalizedWebhook L298 `isPaymentAlreadyRefunded`가 status='partial_refunded'를 이미 환불 종료로 간주 → 두 번째 부분 환불 webhook은 게이트에서 skip됨. **즉 현재 동작상 "부분 환불 1회 후 두 번째 부분 환불 webhook은 차단"**. (b) 따라서 실발현은 reconciliation S2 mismatch 수동 환수 또는 향후 admin 수동 부분 환불 경로에서만 가능.
- **심각도 HIGH 사유**: PAY-P2-1이 "다중 부분 환불 호환"을 RefundLog unique 미부여로 설계했으나, 실제로는 isPaymentAlreadyRefunded가 2회차를 막아 **설계 의도(다중 부분 환불)와 런타임 동작(1회 제한)이 불일치**. shared-contracts §17/§22 정합성 결함. 향후 admin 수동 부분 환불(PAY-P2 확장) 도입 시 직접 발현.
- **권장**: refundPaymentAtomically $transaction 내부에 `tx.refundLog.aggregate({ where:{paymentId}, _sum:{amount} })` → 기존 합계 + refundedAmount ≤ payment.amount 검증 추가. + isPaymentAlreadyRefunded와 부분 환불 다회 정책 정합 결정 (§22/§17 정본 갱신).
- **작업량**: ~1.5~2h (검증 로직 + spec + shared-contracts 정합).

### MEDIUM-1 — webhook 동기 처리 (200 즉시 응답 패턴 미적용)

- **위치**: `payment.controller.ts:40` `webhook` 핸들러 → `paymentUseCase.processWebhook` 동기 호출.
- **발견**: webhook 핸들러가 검증+처리를 동기로 수행 후 응답. PAYMENT_SYSTEM_PLAN §2-2 패턴 8 (CERTI inapi 차용 "webhook 200 즉시 + 큐 위임")이 P1으로 권고됐으나 미적용. PAYMENT_AUDIT-2026-05-07 §4 항목 11도 동일 지적.
- **위험**: completePaymentAtomically + refund 트랜잭션이 webhook 요청 안에서 실행 → DB 지연 시 Polar가 timeout 후 재전송 폭주. (멱등성 게이트가 중복은 차단하나 응답 지연 자체는 잔존.)
- **완화 요인**: WebhookRetryQueue(DLQ) + 멱등성 4중 게이트로 중복/손실은 차단됨. 순수 응답 latency 문제.
- **심각도 MEDIUM**: 운영 안정성 영향이나 데이터 정합성 손실 없음. 현 트래픽 규모(월 결제 ~30건 추정)에서 발현 가능성 낮음.
- **권장**: webhook controller가 verify + WebhookRetryQueue(또는 별 큐) enqueue만 → 200 즉시. 처리는 WebhookRetryJob/별 consumer 위임. 또는 트래픽 증가 전까지 보류 (현 규모 수용 가능).
- **작업량**: ~3~4h.

### MEDIUM-2 — 로컬 DB 마이그레이션 stale (CRITICAL로 승격 — §5 참조)

- 본 항목은 §5 CRITICAL로 별도 상술. 여기서는 cross-ref만.

### MEDIUM-3 — Sentry/APM 미연결 (결제 실패 운영 알림 부재)

- **발견**: PAYMENT_AUDIT-2026-05-07 §3 ("운영자 알림 Sentry/APM 미연결") + §4 항목 4 (P1 권고)에서 식별됨. 본 진단 재확인: WebhookRetryJob permanent_failed / reconciliation S2 mismatch / Circuit Breaker OPEN 시 **AuditLog 박제만 — 외부 알림 0건**. 운영자가 admin_audit_logs를 능동 조회해야 인지.
- **심각도 MEDIUM**: 결제 사고(permanent_failed, circuit OPEN) 발생 시 운영자 실시간 인지 불가 → 대응 지연. 단 데이터는 AuditLog에 보존되어 사후 추적 가능.
- **권장**: PAY-P3-I (Circuit Breaker admin UI)와 결합 — admin UI에서 permanent_failed/mismatch/circuit OPEN 대시보드 표출이 최소 대안. Sentry SaaS는 cost-accountant 게이트.
- **작업량**: admin UI 결합 시 P3-I에 흡수 (추가 ~1h). Sentry 정식 도입 시 ~8h (PAYMENT_AUDIT §6 P3-G 추산).

### LOW-1 — cron 시간대 hardcode

- **위치**: `payment-cleanup.job.ts:45` `@Cron('0 0 4 * * *')` — 한국시간대 가정. 컨테이너 TZ가 UTC면 실제 발동은 UTC 4시(KST 13시).
- **발견**: PAYMENT_AUDIT-2026-05-07 §1 이미 식별. 본 진단 재확인. reconciliation(10분 주기)/webhook-retry(5분 주기)는 주기형이라 무관, cleanup(일 1회)만 해당.
- **심각도 LOW**: cleanup은 24h 초과 pending 정리 — 발동 시각이 KST 4시든 13시든 기능 영향 미미 (reconciliation cron이 S3 expire도 커버). 단 운영자 예측과 어긋남.
- **권장**: `@Cron(expr, { timeZone: 'Asia/Seoul' })` 명시 (NestJS @nestjs/schedule 지원). ~10분.

---

## 5. CRITICAL — 로컬 DB 마이그레이션 stale (실측)

**실측 명령 결과** (`grimoire-server/`에서 `npx prisma migrate status`):

```
Datasource "db": PostgreSQL database "grimoire", schema "public" at "localhost:5432"
33 migrations found in prisma/migrations
Following migrations have not yet been applied:
20260505020000_add_webhook_retry_queue
20260510_pay_p2_5_audit_retention_policy
20260510_pay_p3_e_fk_cascade_policy
20260515_user_soft_delete_policy
20260517_credit_overhaul_i_phase
```

**분석**:
- 로컬 localhost:5432 DB에 **결제 관련 마이그레이션 3건 미적용**: PAY-P2-2 (`webhook_retry_queue` 테이블), PAY-P2-5 (`audit_retention` — webhook_events/webhook_retry_queues에 maskedAt/retentionTier 컬럼), PAY-P3-E (`fk_cascade` — 33 FK onDelete 정책).
- **코드는 완료** (git 커밋 + schema.prisma 반영 확인). **로컬 DB만 코드보다 뒤처짐**.
- 영향: 로컬에서 `npm run start:dev` 후 결제 webhook 실패 → WebhookRetryJob이 `webhook_retry_queues` 테이블 접근 시 **런타임 에러** (테이블 부재). PAY-P3-E FK onDelete도 로컬 미반영 → Author 삭제 시 로컬 동작이 prod와 다름.
- **dev/prod DB 상태 — 미확인**: 본 진단은 Azure DB firewall 미개방으로 dev/prod `migrate status` 실측 불가. `PAYMENT_AUDIT-2026-05-07.md` §5-A는 5/7 시점 "dev 29 migrations applied"를 박제했으나 그 후 P2-5/P3-E/USER-SOFT-DELETE/크레딧개편 마이그레이션이 추가됨 — **5/7 이후 dev/prod 적용 여부는 본 진단으로 확인 불가, 추정 금지**.

**심각도 CRITICAL 사유**: "전수검사 완료" 류 보고 후 프로덕션 기초 에러(마이그레이션 누락)는 사용자 ZERO-TOLERANCE 영역. 코드-DB 불일치는 결제 런타임 장애 직결.

**권장 (사용자/메인 액션 — 본 진단은 코드 수정 0건)**:
1. 로컬: `npx prisma migrate dev` (개발 DB 동기화) — 메인/server agent 영역.
2. dev: `prisma migrate status` 실측 → 미적용분 `prisma migrate deploy` (Azure firewall 임시 개방 후, 사용자 승인 영역).
3. prod: 동일 — `크레딧개편 prod migration 진행` 류 키워드 게이트 (TECH_STATUS §2 명시).
4. **본 진단 결론: 잔여 PAY sprint 진입 전에 dev/prod 마이그레이션 status 실측 선행 필수**.

---

## 6. 종합 — "결제기능 고도화" sprint 분할 + 규모 + 의존성

> 잔여 = 진짜 미완 PAY 항목 + 신규 발견 위험. PAY-P1-3 / P2-1 / P2-4는 완료 — sprint 대상 제외.

### 6-1. Sprint 분할 (논리 단위)

| Sprint | 내용 | 규모 | 외부 의존 | 게이트 |
|--------|------|------|-----------|--------|
| **PAY-S1 마이그레이션 동기화** | 로컬/dev/prod migrate status 실측 + 미적용분 apply (PAY-P2-2/P2-5/P3-E 등) | ~1~2h | 0 | dev/prod = 사용자 키워드 게이트 |
| **PAY-S2 다중 부분 환불 한도 검증** (HIGH-1) | refundPaymentAtomically 누적 합계 검증 + isPaymentAlreadyRefunded 정합 + §17/§22 정본 갱신 + spec | ~1.5~2h | 0 | 자율 가능 |
| **PAY-S3 Circuit Breaker admin UI** (PAY-P3-I) | server: admin 엔드포인트 3 + usecase + spec + api-contract. web: 상태 카드 + open/close 버튼 | ~4~6h (server 2~3 + web 2~3) | 0 | 자율 가능 (VCK 면제 — admin neutral-*) |
| **PAY-S4 결제 알림 (Email + SMS 통합)** | EMAIL-P1-1 인증 선행 → Email/SMS 실 어댑터 + 트리거 통합 + 템플릿 + spec | ~14~18h (EMAIL-P1-1 포함) / ~5~7h (인증 완료 가정) | Email SaaS + SMS provider | **차단** — 절대규정 0-1 해제 + cost-accountant COST_AUDIT 필수 |
| **PAY-S5 webhook 비동기화** (MEDIUM-1) | webhook 200 즉시 + 큐 위임 | ~3~4h | 0 | 자율 가능 — 단 현 트래픽 규모상 후순위 |
| **PAY-S6 운영 알림** (MEDIUM-3) | permanent_failed/mismatch/circuit OPEN 운영자 알림 — PAY-S3 admin UI 결합 최소안 / Sentry 정식안 | +1h (S3 결합) / ~8h (Sentry) | Sentry SaaS (정식안) | Sentry = cost-accountant 게이트 |
| **PAY-S7 cron 시간대** (LOW-1) | payment-cleanup cron timeZone 명시 | ~10분 | 0 | 자율 — S2/S3에 끼워넣기 |

### 6-2. Sprint 간 의존성 그래프

```
PAY-S1 마이그레이션 동기화 (~1~2h, 선행 필수 — 다른 sprint의 DB 전제)
  ↓
PAY-S2 다중 부분 환불 한도 (~1.5~2h, 자율) ──┐
PAY-S3 Circuit Breaker admin UI (~4~6h, 자율) ─┼─ 병렬 가능 (상호 독립)
PAY-S7 cron 시간대 (~10분, S2/S3에 흡수) ─────┘
  ↓
PAY-S6 운영 알림 — 최소안은 S3에 흡수 (+1h) / Sentry 정식안은 별도 (cost-accountant 게이트)
  ↓
PAY-S5 webhook 비동기화 (~3~4h, 후순위 — 현 트래픽 수용 가능)

PAY-S4 결제 알림 (Email+SMS) — 독립 트랙, 외부 게이트 2건으로 차단
  └─ 진입 조건: ① 절대규정 0-1 해제 ② cost-accountant COST_AUDIT ③ EMAIL-P1-1 인증 선행
```

### 6-3. 권고 진행 순서 (메인 sprint 계획 입력)

1. **PAY-S1** (마이그레이션 동기화) — 즉시. 다른 모든 sprint의 DB 전제. **CRITICAL 해소**.
2. **PAY-S2 + PAY-S3 + PAY-S7** 병렬 — 자율 진행 가능, 외부 의존 0. ~6~8h. (S3에 S6 최소 알림 흡수.)
3. **PAY-S5** (webhook 비동기화) — 후순위. 현 트래픽 규모상 보류 가능.
4. **PAY-S4** (결제 알림) — 사용자 게이트 3건 해제 후. cost-accountant COST_AUDIT_REPORT 선행 필수 (외부 API 마진 검증). EMAIL-P1-1 인증 시스템과 통합 진행 권장.

### 6-4. 자율 가능 vs 차단 요약

- **자율 진행 가능 (외부 의존 0)**: PAY-S1, S2, S3, S5, S7 — 합계 ~10~14h.
- **차단 (게이트 필요)**: PAY-S4 결제 알림 — 절대규정 0-1 해제 + cost-accountant + EMAIL-P1-1. PAY-S6 Sentry 정식안 — cost-accountant.

---

## 7. 진단 메타 — 확인/미확인 명시

| 항목 | 상태 |
|------|------|
| 완료 PAY-P0~P3 코드 (15 파일) | ✅ 실제 Read 확인 |
| git log PAY 커밋 증거 | ✅ 실측 (`git log` develop) |
| 결제 spec it 카운트 (168) | ✅ 실측 (`grep -c it`) |
| 로컬 DB 마이그레이션 status | ✅ 실측 (`prisma migrate status` localhost:5432) |
| **dev/prod DB 마이그레이션 status** | ❌ **미확인** — Azure firewall 미개방. 추정 안 함. |
| EmailServicePort / SmsServicePort / NullAdapter | ✅ 실제 Read 확인 |
| payment.usecase 결제 알림 트리거 호출 | ✅ 실측 0건 (`grep -rn sendPaymentNotification`) |
| app.module Email/Sms DI 등록 | ✅ 실측 0건 (`grep EmailService src/app.module.ts`) |
| admin.controller circuit 엔드포인트 | ✅ 실측 0건 |
| `npm test` / `npm run build` 전체 실행 | ❌ 미실행 — 본 작업은 순수 진단 (코드 수정 0건)으로 빌드/테스트 트리거 불요. spec 카운트는 정적 grep. |

**진단 한계**: dev/prod DB 실태는 본 진단으로 확인 불가 — PAY-S1 진입 시 사용자 협력(Azure firewall) 필요. 본 리포트의 dev/prod 마이그레이션 관련 서술은 전부 "미확인" 명시 — 추정 0건.

---

## 8. 변경 이력

- 2026-05-18: 본 진단 리포트 신설. 결제 파이프라인 정밀진단 — 완료 PAY-P0~P3 건강 양호(회귀 0) + 잔여 4건 실태(PAY-P1-3/P2-1/P2-4 완료 / P1-2·SMS Port만 / P3-I 미착수) + 신규 위험 5건(HIGH 1/MEDIUM 3/LOW 1) + CRITICAL 1건(로컬 DB stale) + sprint 7분할. 코드 수정 0건 — 순수 진단. 정본: 본 파일이 5/18 시점 결제 파이프라인 진단 정본 (PAYMENT_SYSTEM_PLAN / PAYMENT_AUDIT-2026-05-07 보강 — 직전 PAYMENT_NEXT_STEPS·PAYMENT_READINESS_AUDIT는 5/3~4 시점 stale 확인).
