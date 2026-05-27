# 작업 계획: EMAIL-POLAR-READY — 외부 게이트 통과 즉시 활성화 사전 박제 (writing-plans)

> 작성: 2026-05-27 / grimoire-planner (Initializer 패턴) / **계획 수립 전용 — 코드 변경 0건**
> 사용자 요청 verbatim (2026-05-27): "내가 이메일이든 KYC든 설정하면 바로 정상 동작 가능하게 미리 설정들 및 구현사항 정리해서 진행"
> 근거 정본:
>   - `reports/PAYMENT_BACKLOG_AUDIT_20260523.md` §2 (Polar/Email 게이트 매트릭스) + §5 (사용자 결정 게이트 #2, #3) + §7 (최종 권장 진행 순서)
>   - `.claude/shared-contracts.md` §11/§17/§19/§22/§27/§30 (PAY-P0~P3 + CC-5 회귀 0 보존)
>   - `grimoire-server/docs/ai-cost-table.md` §0 (1pt = ₩0.09856 §0 검증 단가) + §4 (멤버십 §0 PASS)
>   - `PLANNING_GRIMOIRE.md` §0 (크레딧-원가 철칙 — 안전배수 ≥3.0×)
>   - `grimoire-server/src/domain/port/outbound/email-service.port.ts` (3 메서드 인터페이스 박제 완료)
>   - `grimoire-server/src/domain/port/outbound/sms-service.port.ts` (provider 4종 박제 완료)
>   - `grimoire-server/src/application/subscription/start-subscription.usecase.ts:53-74` (graceful 503 정합)
>   - `grimoire-web/src/app/dashboard/membership/page.tsx:38-40` (단일 진입점 `handleSelect`)
> 적용 양식: `.claude/skills/writing-plans/SKILL.md` (2~5분 sub-task / [MUST]·[SHOULD]·[NICE] / 위험도 🔴🟡🟢 / 의존 / rollback / 검증 게이트)
> 구조 정본: `.claude/state/sprint-cc5-subscription-plan-draft.md` (CC-5 계획과 동일 섹션 구조·포맷)
> 범위: **사용자 액션 1~2줄로 라이브 전환되도록 server/web/secret/web env 사전 박제**
>       — Polar KYC 통과 즉시 + Email SaaS 자격증명 수령 즉시 — 두 게이트 모두에 대해 "외부 SDK import 0건 유지하면서 어댑터 + factory + UseCase 호출점 사전 박제" 패턴 적용.
>       사용자 절대 규정 0-1(외부 API 신규 의존 보류) **정합 유지** — NullAdapter default + EMAIL_PROVIDER=null 기본값.

---

## 0. 진행 순서 + 의존 개요

```
[현 상태 — 2026-05-27 박제 정합]
  EmailServicePort (3 메서드) + NullEmailAdapter ──completed── shared-contracts 미박제
  SmsServicePort (4 provider) + NullSmsAdapter ──completed── shared-contracts §19
  StartSubscriptionUseCase graceful 503 ──completed── shared-contracts(미박제, CC-5 박제 박제)
  initiateSubscriptionCheckout adapter ──completed── env 미설정 시 null
  Polar 4 충전 product + 2 구독 product 등록 ──completed── env 박제 완료
  web MembershipPage ──completed── handleSelect 단일 진입점
                                                       │
   Phase A — Polar KYC 즉시 라이브 전환 (web 1줄)      │
   (env flag NEXT_PUBLIC_SUBSCRIPTION_LIVE 분기)       │
                                                       │
         ┌─────────────────────────────────────────────┘
         │
         ├── Phase B — Email factory 박제 (외부 SDK import 0건 유지)
         │   (EMAIL_PROVIDER=null|resend|ses 분기, NullAdapter default)
         │
         ├── Phase C — EMAIL-P1-1 인증 UseCase (NullAdapter dev 진입 가능)
         │   (Prisma 1 신 모델 + Domain + UseCase + HTTP 2 endpoint)
         │
         ├── Phase D — PAY-S4 결제 알림 UseCase (NullAdapter dev 진입 가능)
         │   (payment.usecase/refund-payment.usecase 호출점 박제, NullAdapter 시 no-op)
         │
         └── Phase E — Secret Manager placeholder + 사용자 매뉴얼
             (GCP Secret Manager 4 placeholder + Cloud Run env 매핑 + INFRASTRUCTURE.md 부록)
```

- **Phase A는 web 단독** (server 변경 0). env flag 분기로 사용자가 Polar KYC 통과 시 web Cloud Run env 변경 + 재배포만으로 라이브 전환.
- **Phase B+C+D는 server 단독** (web 영향 0). 외부 SDK import 0건 유지 — NullAdapter가 default → 사용자 절대 규정 0-1 정합. 사용자 G1 해제 후 ResendEmailAdapter 추가만 별도 micro-sprint.
- **Phase E는 인프라 단독** (server/web 변경 0). GCP Secret Manager에 placeholder secret 박제 + Cloud Run env reference 박제. 사용자가 실 API key 발급 시 `gcloud secrets versions add` 1줄 + env `EMAIL_PROVIDER=resend` 갱신 1줄로 라이브.
- **Phase 의존성 최소화** — Phase A는 web 단독·즉시 가능. Phase B+C+D는 server 순차. Phase E는 Phase B+D 완료 후 (env 참조가 안정된 후 placeholder 박제).
- **graceful 설계가 본 sprint의 단일 최대 설계 결정** — 모든 Phase에서 "env 미설정 시 NullAdapter / env 설정 시 실 어댑터" 분기. 사용자가 env 1~2줄 박제하는 순간 자동 전환.

### 예상 총 시간

- **규모 M** — 본 계획 sub-task 합산 ~8.5~12h.
- sub-task 총 **약 42개** (S0 6 + Phase A 5 + Phase B 9 + Phase C 11 + Phase D 8 + Phase E 5 + 마무리 3, 추후 §11 확정).
- **분할 근거**:
  - ≥30분 + **결제·인증 도메인** (CLAUDE.md §9 결제 원자성 절대 규칙 + 인증 토큰 보안) + Polar KYC 통과 후 web env 변경만으로 즉시 결제 활성 → 회귀 시 사용자 결제 즉시 차단 위험
  - Email factory는 외부 SDK import 0건 유지가 어려운 부분 — SDK는 npm install만, import는 어댑터 파일 내부 dynamic import 패턴으로 회피
  - sub-task 단위 검증 게이트 + git commit 단위 rollback 필수

---

## 1. S0 — 선행: 현 상태 정밀 재확인 (착수 게이트)

> PAYMENT_BACKLOG_AUDIT 박제 5/23 시점 → 5/27 GCP 마이그레이션 후 환경 변경 → S0가 **현행 재실측**.
> ⚠️ Phase D 시점에 SmsServicePort 정합 — payment-notification.usecase가 EmailServicePort + SmsServicePort 양측 호출 박제.

### 1-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| S1a | `polar.adapter.ts:273-330` `initiateSubscriptionCheckout` 현행 Read — env 미설정 시 null + CircuitBreaker 래핑 정합. 사용자 KYC 통과 후 env 박제 시 자동 정상 검증 입력 | [MUST] | 🟢 | 5분 | - | `initiateSubscriptionCheckout` 현행 정합 박제 |
| S1b | `start-subscription.usecase.ts:53-74` graceful 503 분기 현행 Read — adapter 미구현 503 + env 미설정 503 정합 확인 | [MUST] | 🟢 | 4분 | - | graceful 분기 2단 현행 박제 |
| S1c | `email-service.port.ts` 현 인터페이스 Read — 3 메서드(sendVerification/sendPasswordReset/sendPaymentNotification) + 5 provider type 확정. `null` 단일 어댑터 박제 + 4 provider 미박제 확인 | [MUST] | 🟢 | 5분 | - | `EmailServicePort` 3 메서드 + provider 5종 박제 |
| S1d | `sms-service.port.ts` 현 인터페이스 Read — provider 4종 + `sendPaymentNotification` + `sendVerificationCode` 2 메서드 확정. shared-contracts §19 정합 | [MUST] | 🟢 | 4분 | - | `SmsServicePort` 2 메서드 + provider 4종 박제 |
| S1e | `app.module.ts` EmailServicePort/SmsServicePort DI 현행 grep — 본 계획 작성 중 0 매치 확인 → DI 미연동 확정. Phase B에서 factory provider 박제 입력 | [MUST] | 🟢 | 5분 | - | DI 슬롯 비어있음 확정 (Phase B factory 필요) |
| S1f | `dashboard/membership/page.tsx:38-40` `handleSelect` 단일 진입점 현행 Read — 모든 구독 액션이 `setComingSoonOpen(true)` 1개 함수로 수렴. Phase A env flag 분기 입력 | [MUST] | 🟢 | 4분 | - | web 단일 진입점 현행 박제 |

**S0 게이트**: S1a~S1f [MUST] 6건 완료 = 현 박제 정합 재확인 완료 → Phase A 진입 허가. 미확인 잔존 시 본 작업 착수 금지.

> Polar test mode 잔존(`reference_polar_setup.md`) 확인은 §3 사용자 게이트에서 진행 — 코드 게이트 0건.

---

## 2. sprint 분할 권고 — Phase A~E 단일 sprint·5 Phase

> PAYMENT_BACKLOG_AUDIT §7 — KYC + Email SaaS 양측 외부 게이트 통과 즉시 라이브를 사용자 요청 verbatim 정합. planner가 단일 sprint vs 분리를 권고.

### 2-1. 권고 — **단일 sprint·5 Phase** (분리 안 함)

| 案 | 구조 | 장점 | 단점 |
|---|---|---|---|
| **案 ① 분리** — Phase A 단독 / Phase B+C+D+E 별도 sprint | Phase A web 1줄 sprint → server sprint 분리 | sprint 단위 작음 | **목적이 동일** — 사용자 요청 verbatim "이메일이든 KYC든 설정하면 바로 동작" — 양측 게이트 모두 사전 박제가 목적. Phase 분할이 회귀 위험 분산이 아닌 단지 작업 분할이라면 단일 sprint·Phase 게이트가 더 정합 |
| **案 ② 단일 sprint·5 Phase (권고)** | Phase A (web) → Phase B (factory) → Phase C (EMAIL-P1-1) → Phase D (PAY-S4) → Phase E (Secret Manager) 순차 | Email factory(Phase B)가 박제되면 EMAIL-P1-1·PAY-S4 UseCase(Phase C+D)가 동일 DI 슬롯 사용 — Phase 게이트 단계 검증 가능. Phase E는 마지막에 placeholder 박제 — env reference 안정 후 안전 | sub-task 약 42개로 큼 — Phase 게이트로 분할 진척 관리 |

**권고 — 案 ② (단일 sprint, Phase A·B·C·D·E 5 Phase)**. 사유:
1. 사용자 요청 verbatim "이메일이든 KYC든 설정하면 바로 동작" — 양측 게이트 목적 동일 → 단일 sprint
2. EMAIL-P1-1 (Phase C) + PAY-S4 (Phase D)가 동일 `EmailServicePort` DI 슬롯 공유 → Phase B factory 박제 후 양측 작업 자연 진행
3. Phase 게이트가 분할 진척 + 회귀 차단 — Phase A 완료 후 web 즉시 deployable, Phase B+C+D 완료 후 server jest 1097→예상 1150+ PASS, Phase E 완료 후 사용자 매뉴얼 박제

### 2-2. Phase 간 의존

| Phase | 의존 | 병렬 가능? |
|---|---|---|
| Phase A (web env flag) | S0 완료 | ✅ Phase B~E와 병렬 (web/server 독립) |
| Phase B (Email factory) | S0 완료 | Phase C+D는 Phase B 후 |
| Phase C (EMAIL-P1-1 UseCase) | Phase B 완료 | Phase D와 병렬 가능 (별 UseCase) |
| Phase D (PAY-S4 결제 알림) | Phase B 완료 | Phase C와 병렬 가능 |
| Phase E (Secret Manager) | Phase B+D 완료 | env reference 안정 후 |

---

## 3. 외부 게이트 매트릭스 (사용자 결정 영역)

### 3-1. Polar 게이트 (Phase A 활성화 게이트)

| 게이트 | 현 상태 | 해소 조건 | 코드/문서 영향 |
|---|---|---|---|
| **G-Polar-1**. Polar KYC 제출 + 승인 | 🔴 미제출 | Polar Dashboard `Settings → Account` 진입 → KYC + 한국 payout 등록 + Polar support 승인 대기 (수일~수주) | server/web 코드 변경 0건 |
| **G-Polar-2**. Polar test mode → live 전환 | 🔴 test mode | G-Polar-1 통과 후 Polar Dashboard에서 자동 전환 | server/web 코드 변경 0건 |
| **G-Polar-3**. web env `NEXT_PUBLIC_SUBSCRIPTION_LIVE=true` 박제 | 🔴 미설정 | G-Polar-1+2 통과 후 사용자 단독 액션 — `gcloud run services update grimoire-web-prod --update-env-vars NEXT_PUBLIC_SUBSCRIPTION_LIVE=true` + 자동 재배포 | web 1줄 (Phase A 박제) |

**G-Polar-1/2/3 통과 후 즉시 라이브** — Phase A 박제로 사용자 액션 1줄(env 갱신)로 자동 전환.

### 3-2. Email 게이트 (Phase B+C+D+E 활성화 게이트)

| 게이트 | 현 상태 | 해소 조건 | 코드/문서 영향 |
|---|---|---|---|
| **G-Email-1**. 사용자 절대 규정 0-1 해제 | 🔴 미해제 | 사용자가 "외부 API 신규 의존(Email SaaS) 진입 한다" 명시 | UseCase 코드 0건 (NullAdapter→ResendAdapter 어댑터만 추가) |
| **G-Email-2**. cost-accountant SaaS 단가 비교 | 🔴 미진행 | Resend (무료 3k/월 / 유료 $20/50k) vs SendGrid (무료 100/일 / 유료 $19.95/40k) vs Postmark ($15/10k) → cost-accountant 위임 → §0 PASS | `ai-cost-table.md` 신 항목 1건 (월 운영 비용 박제) |
| **G-Email-3**. SaaS API key 발급 | 🔴 미발급 | G-Email-1+2 통과 후 사용자가 SaaS dashboard에서 API key 생성 | Secret Manager `resend-api-key-{dev,prod}-an1` placeholder→실값 갱신 |
| **G-Email-4**. Cloud Run env `EMAIL_PROVIDER=resend` 갱신 | 🔴 미설정 | G-Email-3 완료 후 사용자 단독 액션 — `gcloud run services update grimoire-server-prod --update-env-vars EMAIL_PROVIDER=resend` + 자동 재배포 | server env 1줄 |
| **G-Email-5** (선택). ResendEmailAdapter 추가 | 🔴 미작성 | G-Email-1+2 통과 후 별도 micro-sprint 진입 (본 sprint **OUT** — 외부 SDK import 0건 유지) | server adapter 1건 + spec 5건 (별 sprint) |

**G-Email-1+2+3+4 통과 후 즉시 라이브** (G-Email-5 별 sprint) — Phase B factory가 `EMAIL_PROVIDER=resend` 분기 박제 → 어댑터만 추가하면 자동 전환.

---

## 4. graceful 설계 정합 (단일 최대 설계 결정)

### 4-1. Phase A (Polar KYC) graceful

```typescript
// grimoire-web/src/app/dashboard/membership/page.tsx — Phase A 박제
const live = process.env.NEXT_PUBLIC_SUBSCRIPTION_LIVE === 'true'
const handleSelect = async (tier: MembershipTier) => {
  if (!live) {
    setComingSoonOpen(true)  // 현 박제 — Polar KYC 미통과 시
    return
  }
  // Polar KYC 통과 후 — 실 checkout 호출
  try {
    const { paymentUrl } = await api.startSubscriptionCheckout(tier, window.location.href)
    window.location.href = paymentUrl
  } catch (e) {
    // server graceful 503 → toast error
    toast.error('구독 결제를 시작할 수 없습니다. 잠시 후 다시 시도해주세요.')
  }
}
```

- **flag 미설정 (default)** → 현 박제 `setComingSoonOpen` 동작 — 사용자 결제 시도 시 "준비중" 모달
- **flag 설정 (Polar KYC 통과 후)** → 실 checkout 호출. server graceful 503 분기는 그대로 (env 미설정 시 503)
- **회귀 안전** — 현 web spec(MembershipPlans.test.tsx) 영향 0건. 신 spec 1건만 추가(env flag 분기)

### 4-2. Phase B (Email factory) graceful

```typescript
// grimoire-server/src/app.module.ts — Phase B 박제
{
  provide: 'EmailServicePort',
  useFactory: (config: ConfigService) => {
    const provider = config.get<string>('EMAIL_PROVIDER', 'null')
    switch (provider) {
      case 'resend': return new ResendEmailAdapter(config)  // 별 sprint G-Email-5에서 신설
      case 'ses': return new SesEmailAdapter(config)  // 별 sprint G-Email-5에서 신설
      default: return new NullEmailAdapter()
    }
  },
  inject: [ConfigService],
}
```

- **EMAIL_PROVIDER=null (default)** → NullEmailAdapter — 외부 API 호출 0건, logger.warn만
- **EMAIL_PROVIDER=resend (G-Email-3+4 통과 후)** → ResendEmailAdapter — 실 발송
- **외부 SDK import 0건** — `ResendEmailAdapter` 파일이 dynamic import (`await import('resend')`)로 SDK 로딩 → npm install만 하고 미사용 시 런타임 부담 0

### 4-3. Phase C (EMAIL-P1-1) graceful

```typescript
// grimoire-server/src/application/auth/email-verification.usecase.ts — Phase C 박제
async request(input: { authorId: string; email: string }): Promise<void> {
  const token = await this.generateToken(input.email)  // crypto.randomBytes
  await this.repo.create({ ... })  // DB 박제 (NullAdapter여도 토큰 박제는 정상)
  const result = await this.emailService.sendVerificationEmail({
    to: input.email,
    token,
    expireAt: new Date(Date.now() + 3600_000),
  })
  this.logger.log(`이메일 인증 토큰 발급 — provider=${result.provider} messageId=${result.messageId}`)
  // NullAdapter면 messageId=null + logger.warn만 — 토큰은 DB에 박제됨
}
```

- **NullAdapter (default)** → 토큰 발급 + DB 박제 + logger.warn — 실 발송 0
- **ResendAdapter (G-Email-1~4 통과 후)** → 토큰 발급 + DB 박제 + 실 발송
- **dev 진입 가능** — NullAdapter여도 토큰 검증 흐름(verifyToken)은 정상 동작 → e2e spec 가능

### 4-4. Phase D (PAY-S4) graceful

```typescript
// grimoire-server/src/application/payment/payment.usecase.ts — Phase D 박제
async processWebhook(event: NormalizedWebhookEvent) {
  // 기존 처리 (현 박제 그대로) +
  if (event.status === 'success') {
    await this.notificationUseCase.notifyChargeSuccess(payment, author)  // 신 호출
  }
  if (event.status === 'cancel') {
    await this.notificationUseCase.notifyRefundProcessed(payment, refundLog)  // 신 호출
  }
}

// payment-notification.usecase.ts — Phase D 신설
async notifyChargeSuccess(payment: PaymentRecord, author: AuthorRecord) {
  if (!this.emailService.isEnabled()) {
    // NullAdapter — logger.log + return (외부 호출 0)
    return
  }
  await this.emailService.sendPaymentNotification({
    to: author.email,
    type: 'payment_success',
    payload: { paymentId, amount, credits, productName },
  })
}
```

- **NullAdapter (default)** → `isEnabled()=false` → 호출 0
- **ResendAdapter (G-Email-1~4 통과 후)** → 실 발송
- **결제 트랜잭션 원자성 보존** — 알림 호출은 `$transaction` 외부에서 (alert 실패가 결제 롤백 유발 금지)
- **dev 진입 가능** — NullAdapter여도 호출점은 박제됨 → 사용자 G-Email-1 해제 후 자동 전환

### 4-5. Phase E (Secret Manager) graceful

```bash
# GCP Secret Manager 박제 — Phase E
gcloud secrets create resend-api-key-prod-an1 \
  --replication-policy="user-managed" \
  --locations="asia-northeast1"
echo -n "placeholder" | gcloud secrets versions add resend-api-key-prod-an1 --data-file=-

# Cloud Run env reference 박제
gcloud run services update grimoire-server-prod \
  --update-secrets=RESEND_API_KEY=resend-api-key-prod-an1:latest \
  --update-env-vars=EMAIL_PROVIDER=null
```

- **placeholder secret + EMAIL_PROVIDER=null** → 실 호출 0
- **사용자 G-Email-3 통과 후** → `gcloud secrets versions add resend-api-key-prod-an1 --data-file=-` 1줄 + `gcloud run services update --update-env-vars=EMAIL_PROVIDER=resend` 1줄 → 자동 재배포 + 라이브

---

## 5. Phase A — Polar KYC 즉시 라이브 전환 (web 1줄)

> 사용자 G-Polar-1+2+3 통과 시 자동 활성화되도록 web env flag 분기 박제. server 변경 0건.

### 5-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| A1 | `MembershipPlans.tsx` props 확장 — `live?: boolean` 추가 (옵션, default false) + 액션 버튼 라벨 분기 (live=true 시 "구독하기" 유지, false 시 "준비중" 표시 옵션) | [MUST] | 🟢 | 8분 | S0 | spec 1건 추가 (props live=true/false 분기 PASS) |
| A2 | `dashboard/membership/page.tsx` `live` flag 도입 — `const live = process.env.NEXT_PUBLIC_SUBSCRIPTION_LIVE === 'true'`. handleSelect 분기 박제 — live=true 시 `api.startSubscriptionCheckout(tier, window.location.href)` 호출 → `window.location.href = paymentUrl`. live=false 시 현 박제(`setComingSoonOpen(true)`) 그대로 | [MUST] | 🟡 | 12분 | A1 | spec 1건 (live=true 시 api 호출 + redirect / live=false 시 모달) |
| A3 | `api.ts` `startSubscriptionCheckout(tier, returnUrl)` 신 함수 박제 — BFF 프록시 `POST /api/subscriptions/checkout` 호출. 응답 `{ paymentUrl, tradeNo }` 반환. server 측 endpoint는 이미 박제됨(CC-5) | [MUST] | 🟢 | 6분 | - | spec 1건 (api 호출 + 응답 파싱) |
| A4 | `dashboard/membership/page.tsx` error 분기 박제 — `try/catch` server 503 시 `toast.error('구독 결제를 시작할 수 없습니다. 잠시 후 다시 시도해주세요.')`. 사용자 입장 UX 정합 | [MUST] | 🟡 | 5분 | A2 | spec 1건 (503 → toast.error / 200 → redirect) |
| A5 | Playwright e2e — `membership.e2e.ts` 신설 — flag 미설정 시 모달 / flag=true 시 redirect 시뮬 (api mock). Polar 실 호출 0건 (mock) | [SHOULD] | 🟡 | 15분 | A4 | e2e 2건 PASS |

**Phase A 게이트**: A1~A4 [MUST] 4건 완료 + spec PASS = Phase A 완료. A5는 [SHOULD] — 시간 압박 시 후속 sprint.

**사용자 라이브 액션** (G-Polar-1+2 통과 후):
1. Polar Dashboard에서 KYC + 한국 payout 승인 통과 확인
2. `gcloud run services update grimoire-web-prod --region asia-northeast1 --update-env-vars NEXT_PUBLIC_SUBSCRIPTION_LIVE=true` (1줄)
3. 자동 재배포 (~3분)
4. **종료** — 사용자 구독 클릭 시 Polar checkout으로 redirect, 결제 완료 시 webhook → MembershipPlan 생성 자동

---

## 6. Phase B — Email factory 박제 (외부 SDK import 0건)

> EMAIL_PROVIDER env 분기 + factory pattern + NullAdapter default. ResendAdapter/SesAdapter는 stub 파일만 신설 (실 구현은 별 sprint, dynamic import로 SDK 부담 0).

### 6-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| B1 | `app.module.ts` EmailServicePort factory provider 박제 — `useFactory: (config) => switch(EMAIL_PROVIDER) { case 'resend': new ResendEmailAdapter(config); case 'ses': new SesEmailAdapter(config); default: new NullEmailAdapter() }`. inject: [ConfigService] | [MUST] | 🟡 | 10분 | S0 | factory provider 박제 + e2e 부팅 시 NullAdapter DI 확인 |
| B2 | `infrastructure/email/email.factory.ts` 신설 — factory 로직 분리 (app.module 비대화 방지). `createEmailService(config: ConfigService): EmailServicePort` 함수 박제 | [MUST] | 🟢 | 8분 | B1 | spec 1건 (provider별 인스턴스 반환) |
| B3 | `adapter/outbound/email/resend-email.adapter.ts` **stub만 신설** — `@Injectable() class ResendEmailAdapter implements EmailServicePort` 3 메서드 throw `new Error('Resend adapter not implemented — 별 sprint G-Email-5')`. isEnabled()=false (env 미박제 시). getProviderName()='resend'. **dynamic import 미박제** (별 sprint) | [MUST] | 🟢 | 12분 | B2 | spec 1건 (throw 패턴 RED 재현 + isEnabled false) |
| B4 | `adapter/outbound/email/ses-email.adapter.ts` **stub만 신설** — B3 동일 패턴 (AWS SDK). 별 sprint G-Email-5에서 실 구현 | [MUST] | 🟢 | 10분 | B2 | spec 1건 (throw 패턴 + isEnabled false) |
| B5 | `email.factory.spec.ts` — EMAIL_PROVIDER=null/resend/ses/sendgrid/postmark 5 분기 spec. null→NullAdapter, resend→ResendAdapter, ses→SesAdapter, 미지원(sendgrid/postmark)→NullAdapter fallback + logger.warn | [MUST] | 🟡 | 10분 | B4 | spec 5건 (provider 분기 + fallback) |
| B6 | SmsServicePort factory 동일 박제 — `infrastructure/sms/sms.factory.ts` 신설 + `app.module.ts` 박제. KakaoBizmessageAdapter/NhnCloudSmsAdapter/TwilioSmsAdapter stub 3건 (B3+B4 패턴). 본 sprint Phase D에서 호출 검증 | [SHOULD] | 🟡 | 20분 | B5 | factory 3 분기 + null default |
| B7 | `app.module.ts` SmsServicePort DI 박제 (B6 결과 연동) | [SHOULD] | 🟢 | 5분 | B6 | DI 박제 + e2e 부팅 확인 |
| B8 | `infrastructure/email/templates/` 디렉토리 신설 — 5 템플릿 stub(verification.html, password-reset.html, payment-success.html, payment-failed.html, payment-refunded.html). 한국어 본문 + 변수 placeholder(`{{displayName}}`/`{{amount}}`/`{{credits}}`/...) 박제. ResendAdapter 실 구현 시 read | [SHOULD] | 🟢 | 15분 | B5 | 5 템플릿 파일 + 변수 placeholder 박제 |
| B9 | shared-contracts §N 신설 박제 — "EmailServiceFactory" + "SmsServiceFactory" 5 provider 분기 + NullAdapter default 패턴. 변경 이력 1줄 | [MUST] | 🟢 | 8분 | B7 | shared-contracts §N 박제 |

**Phase B 게이트**: B1~B5 + B9 [MUST] 6건 완료 + spec PASS = Phase B 완료. B6~B8 [SHOULD] 권장.

**외부 SDK 0건 검증**:
- `grep -rn "from 'resend'\|from '@aws-sdk/client-ses'\|from '@sendgrid'" src/` → 0 매치 ([MUST])
- `package.json` `dependencies` `resend`/`@aws-sdk/client-ses`/`@sendgrid/mail` 미박제 ([MUST])

---

## 7. Phase C — EMAIL-P1-1 인증 시스템 (NullAdapter dev 진입 가능)

> 도메인 모델 + UseCase + HTTP endpoint + Prisma 신 모델. NullAdapter 시 토큰 발급/검증 정상 (실 발송만 0).

### 7-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C1 | `domain/model/email-verification-token.ts` 신설 — 값 객체 `EmailVerificationToken { id, authorId, email, tokenHash, expireAt, redeemedAt, createdAt }`. tokenHash는 sha256(token+pepper) | [MUST] | 🟡 | 10분 | Phase B | 도메인 모델 박제 + 값 객체 spec 1건 |
| C2 | `prisma/schema.prisma` 신 모델 `EmailVerificationToken` 박제 — id/authorId/email/tokenHash/expireAt/redeemedAt/createdAt + index(authorId, expireAt) + tokenHash unique. 마이그레이션 1건 `20260527_email_verification_token` | [MUST] | 🟡 | 8분 | C1 | migration apply dev/prod 후 schema 확인 |
| C3 | `domain/port/outbound/email-verification-token-repository.port.ts` 신설 — `create(input)`, `findByTokenHash(hash)`, `markRedeemed(id)`, `deleteExpired()` 4 메서드 | [MUST] | 🟢 | 6분 | C1 | port 박제 |
| C4 | `adapter/outbound/persistence/prisma-email-verification-token.repository.ts` 신설 — port 구현 + Prisma. spec 4건 | [MUST] | 🟡 | 15분 | C2, C3 | spec 4건 PASS |
| C5 | `application/auth/email-verification.usecase.ts` 신설 — `request(authorId, email)` + `verify(token)` 2 메서드. crypto.randomBytes(32) 토큰 + sha256 hash + DB 박제 + EmailServicePort.sendVerificationEmail. verify는 hash 매칭 + expireAt 검증 + Author.verified=true + markRedeemed | [MUST] | 🟡 | 18분 | C4 | spec 6건 (req/verify happy + expire/redeem/dupRequest 등) |
| C6 | `application/auth/password-reset.usecase.ts` 신설 — C5 동일 패턴, request/verify 2 메서드. Author.passwordHash 갱신 | [MUST] | 🟡 | 15분 | C5 | spec 5건 |
| C7 | `adapter/inbound/http/controller/auth.controller.ts` 확장 — `POST /auth/email/verify-request` + `POST /auth/email/verify-confirm` + `POST /auth/password/reset-request` + `POST /auth/password/reset-confirm` 4 endpoint. DTO + Throttler(@Throttle 1/min) | [MUST] | 🟡 | 18분 | C6 | spec 4건 (HTTP 200/400/429 케이스) |
| C8 | `api-contract.md` 4 endpoint 박제 — request body / response / error code / Throttle 정합 | [MUST] | 🟢 | 8분 | C7 | docs 박제 |
| C9 | `data-model.md` `EmailVerificationToken` 모델 박제 — Prisma schema 정합 | [MUST] | 🟢 | 5분 | C2 | docs 박제 |
| C10 | dev e2e — `email-verification.e2e.ts` 신설 — NullAdapter 시 토큰 발급+검증 흐름 PASS (실 발송 0건, logger.warn 박제만) | [MUST] | 🟡 | 15분 | C7 | e2e PASS + logger.warn 박제 확인 |
| C11 | shared-contracts §N 신설 박제 — "EmailVerificationTokenPolicy" — 토큰 형식 + 만료 + 멱등성 + Throttle 정합. 변경 이력 1줄 | [MUST] | 🟢 | 8분 | C8 | shared-contracts §N 박제 |

**Phase C 게이트**: C1~C11 [MUST] 11건 완료 + spec PASS + e2e PASS + migration apply = Phase C 완료.

**보안 정합**:
- 토큰 평문 미저장 (sha256 hash + pepper)
- Throttle @Throttle 1/min — 무차별 대입 차단
- expireAt 1h (verification) / 30min (password reset)
- redeemedAt 박제 — 재사용 차단

---

## 8. Phase D — PAY-S4 결제 알림 UseCase (NullAdapter dev 진입 가능)

> payment.usecase + refund-payment.usecase + subscription-webhook.usecase 호출점 박제. NullAdapter 시 호출 0건 (`isEnabled()=false` 가드).

### 8-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| D1 | `application/payment/payment-notification.usecase.ts` 신설 — 4 메서드: `notifyChargeSuccess(payment, author)`, `notifyChargeFailed(payment, author)`, `notifyRefundProcessed(payment, refundLog, author)`, `notifySubscriptionRenewal(plan, author)`. 각 메서드 `if (!emailService.isEnabled() && !smsService.isEnabled()) return` 가드 | [MUST] | 🟡 | 20분 | Phase B | spec 4건 (NullAdapter 시 호출 0 / 실 어댑터 시 호출 1) |
| D2 | `payment.usecase.processWebhook` 호출점 박제 — `event.status === 'success'` 분기 후 `await this.notificationUseCase.notifyChargeSuccess(payment, author)`. **$transaction 외부에서** (알림 실패가 결제 롤백 유발 차단). try/catch + logger.error만 (throw 미발생) | [MUST] | 🔴 | 15분 | D1 | spec 2건 (호출 정합 + 알림 실패 시 결제 정상 commit) |
| D3 | `refund-payment.usecase.ts` 호출점 박제 — refund 완료 후 `notifyRefundProcessed`. D2 동일 패턴 (트랜잭션 외부 + try/catch) | [MUST] | 🔴 | 12분 | D2 | spec 2건 |
| D4 | `subscription-webhook.usecase.ts` 호출점 박제 — `subscription.created`/`subscription.updated` 후 `notifySubscriptionRenewal`. D2 동일 패턴 | [MUST] | 🔴 | 12분 | D3 | spec 2건 |
| D5 | `payment.usecase.ts` failed 분기 박제 — Polar webhook `event.status === 'fail'` 시 `notifyChargeFailed`. 현 박제 payment.status='failed' 갱신 후 알림 | [SHOULD] | 🟡 | 10분 | D4 | spec 1건 |
| D6 | SmsServicePort 호출 박제 — Phase B의 B6+B7 완료 후 진입. D1의 각 메서드에 `smsService.sendPaymentNotification` 동시 호출. NullAdapter 시 호출 0 | [SHOULD] | 🟡 | 15분 | D5, Phase B B7 | spec 2건 (sms+email 양측 호출) |
| D7 | `payment-notification.usecase.spec.ts` 통합 spec — NullAdapter dev 진입 시 호출 0 (RED 재현). ResendAdapter Mock 시 호출 1 (GREEN). 4 시나리오 × 2 adapter = 8 케이스 | [MUST] | 🟡 | 20분 | D6 | spec 8건 PASS |
| D8 | shared-contracts §N 신설 박제 — "PaymentNotificationPolicy" — 4 시나리오 + $transaction 외부 + try/catch + NullAdapter 가드 + 재발송 정책(없음). 변경 이력 1줄 | [MUST] | 🟢 | 8분 | D7 | shared-contracts §N 박제 |

**Phase D 게이트**: D1~D4 + D7 + D8 [MUST] 6건 완료 + spec PASS = Phase D 완료. D5+D6 [SHOULD] 권장.

**결제 트랜잭션 원자성 보존 검증**:
- $transaction 내부에서 알림 호출 0건 (grep 검증)
- 알림 실패 시 payment.usecase의 `processed=true` 반환 정합 (알림 실패가 webhook 재시도 유발 차단)
- sensor-payment-idempotency 7/7 PASS 회귀 0건

---

## 9. Phase E — Secret Manager placeholder + 사용자 매뉴얼

> GCP Secret Manager 박제 + Cloud Run env reference + INFRASTRUCTURE.md 부록. 인프라 단독 (server/web 변경 0).

### 9-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| E1 | GCP Secret Manager 4 placeholder 생성 — `resend-api-key-{dev,prod}-an1` + `sendgrid-api-key-{dev,prod}-an1`. placeholder value `"placeholder"`. `gcloud secrets create` × 4 + `gcloud secrets versions add` × 4. asia-northeast1 단일 리전 | [MUST] | 🟡 | 10분 | Phase B+D | `gcloud secrets list --filter="name~resend OR name~sendgrid"` 4 secret 확인 |
| E2 | Cloud Run env reference 박제 — dev/prod server 양측 `--update-secrets=RESEND_API_KEY=resend-api-key-{env}-an1:latest,SENDGRID_API_KEY=sendgrid-api-key-{env}-an1:latest` + `--update-env-vars=EMAIL_PROVIDER=null,SMS_PROVIDER=null` | [MUST] | 🟡 | 10분 | E1 | Cloud Run env 확인 + 재부팅 후 NullAdapter 정합 |
| E3 | SMS Secret Manager 4 placeholder (옵션) — `kakao-bizmessage-key-{dev,prod}-an1` + `nhn-cloud-sms-key-{dev,prod}-an1`. SMS_PROVIDER=null default | [SHOULD] | 🟢 | 10분 | E2 | secret 4 확인 |
| E4 | `INFRASTRUCTURE.md` §부록 신설 — "Email/SMS SaaS 활성화 매뉴얼" 5 step (1. G1 해제, 2. cost-accountant 위임, 3. SaaS 선택 + API key 발급, 4. `gcloud secrets versions add` 1줄, 5. `gcloud run services update --update-env-vars=EMAIL_PROVIDER=resend` 1줄). 각 step 명확 + 명령어 박제 | [MUST] | 🟢 | 15분 | E3 | INFRASTRUCTURE.md 부록 박제 |
| E5 | `INFRASTRUCTURE.md` §부록 신설 — "Polar KYC 통과 후 라이브 매뉴얼" 4 step (1. Polar Dashboard KYC + payout 승인 확인, 2. Polar test mode → live 전환 확인, 3. `gcloud run services update grimoire-web-prod --update-env-vars NEXT_PUBLIC_SUBSCRIPTION_LIVE=true` 1줄, 4. 자동 재배포 ~3분) | [MUST] | 🟢 | 10분 | E4 | INFRASTRUCTURE.md 부록 박제 |

**Phase E 게이트**: E1+E2+E4+E5 [MUST] 4건 완료 = Phase E 완료. E3 [SHOULD] 권장.

**사용자 라이브 액션 매뉴얼 최종 검증**:
- Polar 매뉴얼: 4 step, 명령어 1줄
- Email 매뉴얼: 5 step, 명령어 2줄 (secret + env)
- 매뉴얼 README 또는 INFRASTRUCTURE.md §부록 박제 — 사용자 단독 진행 가능

---

## 10. 위험 매트릭스

| # | 위험 | 위험도 | 완화책 |
|---|---|---|---|
| R1 | Phase A flag 분기 회귀 — Polar KYC 통과 전 flag=true 잘못 설정 시 server 503 → 사용자 결제 시도 차단 | 🟡 | server graceful 503 + web toast.error 박제 (4-4). 사용자 가드 메시지 명확 |
| R2 | Phase B factory 회귀 — EMAIL_PROVIDER 미박제 시 fallback NullAdapter 정합 / 미지원 provider(sendgrid/postmark) 입력 시 fallback NullAdapter | 🟢 | B5 spec 5분기 PASS + logger.warn 박제 |
| R3 | Phase C 마이그레이션 회귀 — `EmailVerificationToken` 신 모델 + index → prod migration 시 lock | 🟡 | dev 우선 apply → 24h 박제 → prod (PAY-S2 패턴) + migration rollback 1건 박제 (down migration) |
| R4 | Phase D 결제 트랜잭션 회귀 — 알림 호출이 $transaction 내부에 박제될 시 알림 실패 시 결제 롤백 → CRITICAL | 🔴 | D2/D3/D4 `$transaction` 외부 박제 + try/catch + sensor-payment-idempotency 회귀 검증 |
| R5 | Phase D 결제 알림 spam — webhook 재시도 시 알림 N회 발송 위험 | 🟡 | PAY-P0-1 멱등성 게이트(webhookEventRepo)가 차단 (이미 박제) + 알림은 멱등성 게이트 통과 후만 호출 |
| R6 | Phase E secret 회전 정책 미수립 — placeholder→실값 갱신 후 회전 정책 없음 | 🟢 | INFRASTRUCTURE.md §부록에 "1년 1회 회전 권고" 박제 |
| R7 | 외부 SDK import 0건 위반 — Phase B의 stub 어댑터에 SDK import 박제될 시 사용자 절대 규정 0-1 위반 | 🔴 | B3+B4 dynamic import 패턴(`await import('resend')`) 박제 + grep 검증 + package.json dependencies 미박제 검증 |
| R8 | Phase C Throttle 회귀 — @Throttle 미적용 시 무차별 대입 공격 가능 | 🔴 | C7 spec 429 케이스 박제 + e2e 검증 + SECURITY.md §4 체크리스트 박제 |
| R9 | Phase A web env 분기 잘못 작동 — `process.env.NEXT_PUBLIC_*`가 build time 인라인됨 — runtime 갱신이 즉시 적용되지 않을 수 있음 | 🟡 | Next.js 16 — `NEXT_PUBLIC_*`는 build time 인라인됨. Cloud Run 재배포 시점에 새 이미지 빌드 필요 — INFRASTRUCTURE.md §부록 step 3에 명시. **대안**: server BFF `/api/membership/live-flag` endpoint로 runtime 분기 (별 sprint 검토) |
| R10 | Phase D PAY-S4 NullAdapter dev 진입 시 logger.warn 누적 | 🟢 | logger.warn은 PII 마스킹 박제 (현 NullEmailAdapter:75-86) + log rotation 정합 |

---

## 11. AC BDD (acceptance criteria)

### Phase A — Polar KYC 라이브 전환

**AC-A1**: NEXT_PUBLIC_SUBSCRIPTION_LIVE flag 미설정 (default)
- Given 사용자가 `/dashboard/membership` 방문
- When 사용자가 Pro 플랜 "구독하기" 버튼 클릭
- Then `ComingSoonModal` 노출, `api.startSubscriptionCheckout` 호출 0건

**AC-A2**: NEXT_PUBLIC_SUBSCRIPTION_LIVE=true 박제 + server graceful 정상
- Given 사용자가 `/dashboard/membership` 방문 + env flag=true + server env(POLAR_PRODUCT_SUBSCRIPTION_PRO) 박제
- When 사용자가 Pro 플랜 "구독하기" 버튼 클릭
- Then `api.startSubscriptionCheckout('pro', returnUrl)` 호출 → `window.location.href = paymentUrl` redirect

**AC-A3**: NEXT_PUBLIC_SUBSCRIPTION_LIVE=true + server graceful 503 (Polar KYC 통과 전)
- Given env flag=true + server env(POLAR_PRODUCT_SUBSCRIPTION_PRO) 미설정 → server 503
- When 사용자가 Pro 플랜 "구독하기" 버튼 클릭
- Then `toast.error('구독 결제를 시작할 수 없습니다. 잠시 후 다시 시도해주세요.')` 노출

### Phase B — Email factory

**AC-B1**: EMAIL_PROVIDER 미설정 (default)
- Given 서버 부팅 + EMAIL_PROVIDER env 미박제
- When `EmailServicePort` DI 해소
- Then `NullEmailAdapter` 인스턴스 반환, `isEnabled()=false`, `getProviderName()='null'`

**AC-B2**: EMAIL_PROVIDER=resend + ResendAdapter stub
- Given 서버 부팅 + EMAIL_PROVIDER=resend + ResendAdapter stub 신설
- When `EmailServicePort.sendVerificationEmail` 호출
- Then `throw new Error('Resend adapter not implemented')`. dynamic import 미박제 → SDK 로딩 0

**AC-B3**: EMAIL_PROVIDER=sendgrid (미지원)
- Given 서버 부팅 + EMAIL_PROVIDER=sendgrid (factory 미박제 provider)
- When `EmailServicePort` DI 해소
- Then `NullEmailAdapter` fallback + `logger.warn('Unsupported provider: sendgrid → NullAdapter fallback')` 박제

### Phase C — EMAIL-P1-1 인증

**AC-C1**: 이메일 인증 토큰 발급 + NullAdapter 흐름
- Given 사용자 가입 직후 + EMAIL_PROVIDER=null
- When `POST /auth/email/verify-request` 호출
- Then DB `EmailVerificationToken` 1 row 박제 + sha256 hash 저장 + `logger.warn('[NullEmailAdapter] sendVerificationEmail skipped — to=u***@example.com')` 박제 + 200 OK 반환 (외부 발송 0)

**AC-C2**: 이메일 인증 토큰 검증 + redeem
- Given DB에 미만료 토큰 박제
- When `POST /auth/email/verify-confirm { token }` 호출
- Then sha256 hash 매칭 + expireAt 검증 + Author.verified=true + redeemedAt 박제 + 200 OK

**AC-C3**: 만료 토큰 검증
- Given DB에 expireAt 과거 토큰
- When `POST /auth/email/verify-confirm { token }`
- Then 400 Bad Request `{ message: '토큰이 만료되었습니다' }`

**AC-C4**: 재사용 차단
- Given redeemedAt 박제된 토큰
- When `POST /auth/email/verify-confirm { token }`
- Then 400 Bad Request `{ message: '이미 사용된 토큰입니다' }`

**AC-C5**: Throttle @Throttle 1/min
- Given 동일 IP에서 `POST /auth/email/verify-request` 60초 내 2회 호출
- When 2회차 호출
- Then 429 Too Many Requests

### Phase D — PAY-S4 결제 알림

**AC-D1**: 결제 성공 알림 호출 (NullAdapter 시 발송 0)
- Given Polar `order.paid` webhook 수신 + EMAIL_PROVIDER=null + SMS_PROVIDER=null
- When `payment.usecase.processWebhook` 처리
- Then `payment-notification.usecase.notifyChargeSuccess` 호출 1건 + EmailService/SmsService `isEnabled()=false` → 발송 0 + payment.status='completed' commit 정합

**AC-D2**: 알림 실패 시 결제 트랜잭션 보존 (CRITICAL)
- Given EmailService.sendPaymentNotification이 throw (network error)
- When `payment.usecase.processWebhook` 처리
- Then payment.status='completed' commit 정합 (rollback 0) + logger.error 박제 + webhook 200 OK 반환 (재시도 유발 차단)

**AC-D3**: 환불 알림 호출
- Given Polar `order.refunded` webhook 수신
- When `refund-payment.usecase` 처리
- Then `notifyRefundProcessed` 호출 1건 + RefundLog 박제 정합

### Phase E — Secret Manager

**AC-E1**: Cloud Run 부팅 + placeholder secret
- Given GCP Secret Manager `resend-api-key-prod-an1` placeholder 박제 + Cloud Run env reference 박제 + EMAIL_PROVIDER=null
- When server 부팅
- Then env `RESEND_API_KEY=placeholder` 박제 + NullEmailAdapter DI (EMAIL_PROVIDER=null) + 외부 호출 0

**AC-E2**: 사용자 라이브 매뉴얼 정확성
- Given INFRASTRUCTURE.md §부록 박제
- When 사용자가 매뉴얼 step 따라 진행
- Then 5 step 完了 후 Cloud Run env 갱신 + 재배포 자동 + EmailService 라이브

---

## 12. env 매핑 (신 env 박제)

| env | scope | default | 활성 조건 | 박제 위치 |
|---|---|---|---|---|
| `NEXT_PUBLIC_SUBSCRIPTION_LIVE` | web (Cloud Run) | (미박제) | Polar KYC 통과 후 `true` | `dashboard/membership/page.tsx` (Phase A) |
| `EMAIL_PROVIDER` | server (Cloud Run) | `null` | G-Email-1+2+3 통과 후 `resend`/`ses` | `email.factory.ts` (Phase B) |
| `SMS_PROVIDER` | server (Cloud Run) | `null` | G-SMS-1+2+3 통과 후 `kakao`/`nhn` | `sms.factory.ts` (Phase B) |
| `RESEND_API_KEY` | server (Secret Manager) | `placeholder` | G-Email-3 통과 후 실 key | Secret `resend-api-key-{env}-an1` (Phase E) |
| `SENDGRID_API_KEY` | server (Secret Manager) | `placeholder` | G-Email-3 통과 후 실 key | Secret `sendgrid-api-key-{env}-an1` (Phase E) |
| `AWS_SES_REGION` | server (Cloud Run) | (미박제) | SES 선택 시 `ap-northeast-2` | `ses-email.adapter.ts` (별 sprint) |
| `AWS_SES_ACCESS_KEY_ID` | server (Secret Manager) | `placeholder` | SES 선택 시 실 key | Secret `aws-ses-key-{env}-an1` (Phase E, 옵션) |
| `KAKAO_BIZMESSAGE_KEY` | server (Secret Manager, 옵션) | `placeholder` | SMS Kakao 선택 시 실 key | Secret `kakao-bizmessage-key-{env}-an1` (Phase E, 옵션) |

**총 신 env: 5건 필수 (web 1 + server 4) + 옵션 4건**

---

## 13. 마이그레이션 매트릭스

| # | 마이그레이션 | 위험 | rollback | 적용 시점 |
|---|---|---|---|---|
| M1 | `20260527_email_verification_token` — `EmailVerificationToken` 신 모델 + index | 🟡 | down migration 박제 (DROP TABLE) | Phase C C2 |

**총 마이그레이션: 1건 (사용자 제약 ≤2건 정합)**

**마이그레이션 적용 절차**:
1. dev migration apply (`make migrate-dev`)
2. dev e2e 24h 박제
3. prod migration apply (`make migrate-prod`)
4. prod 5/22 PAY-S2 패턴 - 메인 직접 배포 가능

---

## 14. Secret Manager 신설 매트릭스

| # | secret name | 환경 | placeholder value | 적용 시점 |
|---|---|---|---|---|
| SM1 | `resend-api-key-dev-an1` | dev | `placeholder` | Phase E E1 |
| SM2 | `resend-api-key-prod-an1` | prod | `placeholder` | Phase E E1 |
| SM3 | `sendgrid-api-key-dev-an1` | dev | `placeholder` | Phase E E1 |
| SM4 | `sendgrid-api-key-prod-an1` | prod | `placeholder` | Phase E E1 |
| SM5 | `aws-ses-key-dev-an1` (옵션) | dev | `placeholder` | Phase E E3 |
| SM6 | `aws-ses-key-prod-an1` (옵션) | prod | `placeholder` | Phase E E3 |
| SM7 | `kakao-bizmessage-key-dev-an1` (옵션) | dev | `placeholder` | Phase E E3 |
| SM8 | `kakao-bizmessage-key-prod-an1` (옵션) | prod | `placeholder` | Phase E E3 |

**총 Secret Manager 신설: 4건 필수 + 4건 옵션 = 최대 8건**

**Secret 회전 정책** (INFRASTRUCTURE.md §부록 박제):
- 사용자가 실 API key 발급 + Secret Manager 갱신 후 → 1년 1회 회전 권고
- 회전 절차: `gcloud secrets versions add {secret-name} --data-file=<(echo -n "{new-key}")` 1줄

---

## 15. orchestration 위임 매트릭스

| Phase | 담당 agent | 위임 단위 | 의존 |
|---|---|---|---|
| S0 (현 상태 정밀 재확인) | grimoire-planner | 현 박제 정합 재확인 | - |
| Phase A (web env flag) | **grimoire-web** | A1~A5 web sub-task | S0 |
| Phase B (Email factory) | **grimoire-server** | B1~B9 server sub-task | S0 |
| Phase C (EMAIL-P1-1) | **grimoire-server** | C1~C11 server sub-task | Phase B |
| Phase D (PAY-S4) | **grimoire-server** | D1~D8 server sub-task | Phase B |
| Phase E (Secret Manager) | **grimoire-infrastructure** | E1~E5 인프라 sub-task | Phase B+D |
| 마무리 | grimoire-qa | shared-contracts 갱신 + sensor + jest 회귀 검증 + e2e | 모든 Phase |

**병렬 진행 가능**: Phase A (web)와 Phase B+C+D (server)는 독립 → 동시 진행 가능. Phase E는 마지막.

---

## 16. 사용자 결정 게이트

### 게이트 #1. 본 plan-draft 승인
- **결정 내용**: 본 sprint 진입 승인 (구현은 본 plan-draft 승인 후)
- **선행 조건**: 본 plan-draft Read + 동의

### 게이트 #2. Polar KYC + payout 승인 절차 착수 (병렬)
- **결정 내용**: Polar Dashboard에서 KYC + 한국 payout 등록 + Polar support 승인 요청
- **소요**: Polar support 대기 (수일~수주)
- **server 측 코드/문서 변경 0건** — 사용자 단독 액션
- **승인 후**: web env 1줄 갱신만 (Phase A 박제 후)

### 게이트 #3. 절대 규정 0-1 해제 명시 (Email SaaS 진입 조건)
- **결정 내용**: "외부 API 신규 의존(Email SaaS) 진입 한다" 사용자 명시
- **memory** 박제 사항 — 4/30 박제 "외부 api를 쓰는 방향... 나중 과제로 미루고 싶다"
- **해제 후**: cost-accountant Email SaaS 단가 비교 위임 → ResendAdapter / SesAdapter 中 선택 → 별 sprint G-Email-5 진입

### 게이트 #4. Email SaaS 선택 (G-Email-3 완료 게이트)
- **결정 내용**: Resend / SendGrid / SES / Postmark 中 선택
- **cost-accountant 위임 후 §0 PASS 검증 결과 기반**
- **선택 후**: SaaS dashboard에서 API key 발급 → `gcloud secrets versions add` 1줄

---

## 17. 제약 (위반 금지)

| # | 제약 | 검증 |
|---|---|---|
| 1 | 사용자 절대 규정 0-1 정합 유지 — G-Email-1 해제 전 NullAdapter default | `grep -rn "from 'resend'\|from '@aws-sdk/client-ses'" src/` → 0 매치 |
| 2 | 결제 도메인 트랜잭션 원자성 보존 — PAY-P0~P3 + CC-1~5 회귀 0 | sensor-payment-idempotency 7/7 + sensor-payment-reconciliation 10/10 + sensor-refund-atomicity 10/10 PASS |
| 3 | 작가 소설 콘텐츠 수정 0건 | `grep -rn` 작가 본문 패턴 검증 |
| 4 | 마이그레이션 ≤2건 (EmailVerificationToken + 옵션) | Phase C C2 1건 |
| 5 | secret/credential 평문 출력 0건 | NullEmailAdapter PII 마스킹 패턴 정합 (현 박제) + sensor-secret-leak PASS |
| 6 | 사용자 트래픽 영향 0 — NullAdapter dev 진입 시 외부 호출 0건 | spec 검증 + e2e 검증 |
| 7 | 외부 SDK import 0건 — dynamic import 패턴 | grep 검증 + package.json dependencies 미박제 |
| 8 | shared-contracts 즉시 갱신 — Phase B/C/D 인터페이스 변경 시 | `.claude/shared-contracts.md` §N 박제 (B9/C11/D8) |
| 9 | docs 동기화 — api-contract + data-model + INFRASTRUCTURE 갱신 | Phase C C8+C9 + Phase E E4+E5 |
| 10 | CLAUDE.md §9 결제 원자성 절대 규칙 정합 | Phase D R4 위험 완화책 정합 |

---

## 18. 최종 권장 진행 순서

```
[게이트 #1 승인 후]
  → S0 (현 상태 정밀 재확인, 6 sub-task, ~30분)
  ↓
[Phase A (web) — 병렬 가능]                [Phase B (server) — server 단독]
  → A1~A5 (5 sub-task, ~45분)              → B1~B9 (9 sub-task, ~100분)
  ↓                                         ↓
[Phase A 완료 — web deployable]            [Phase B 완료 — factory 박제]
                                            ↓
                                            ↓
                                            ├─[Phase C — EMAIL-P1-1, 병렬]
                                            │  → C1~C11 (11 sub-task, ~135분)
                                            │  ↓
                                            │  [Phase C 완료 — 인증 시스템 박제]
                                            │
                                            └─[Phase D — PAY-S4, 병렬]
                                               → D1~D8 (8 sub-task, ~110분)
                                               ↓
                                               [Phase D 완료 — 알림 박제]
                                            ↓
                                            ↓
[Phase E (인프라)]
  → E1~E5 (5 sub-task, ~55분)
  ↓
[Phase E 완료 — Secret + 매뉴얼 박제]
  ↓
[마무리]
  → shared-contracts §B9/C11/D8 박제 검증
  → jest 1097→예상 1150+ PASS 검증
  → vitest web 226→예상 235+ PASS 검증
  → sensor-payment-idempotency 7/7 회귀 0
  → 3 레포 push + dev 배포 + 24h 박제 + prod 배포
  ↓
[게이트 #2~#4 사용자 진행]
  → Polar KYC + payout 승인 (수일~수주)
  → 절대 규정 0-1 해제 명시 (1줄 발화)
  → cost-accountant Email SaaS 단가 위임 → SaaS 선택
  → SaaS API key 발급 → `gcloud secrets versions add` 1줄
  → `gcloud run services update --update-env-vars EMAIL_PROVIDER=resend` 1줄
  ↓
[자동 라이브 전환]
  → web `NEXT_PUBLIC_SUBSCRIPTION_LIVE=true` 박제 → 구독 결제 라이브
  → server `EMAIL_PROVIDER=resend` 박제 → 결제 알림/이메일 인증 실 발송 라이브
```

---

## 19. 본 plan-draft 정합 자기검증 (Chain-of-Verification)

1. **사용자 요청 verbatim 정합?** ✅ — "이메일이든 KYC든 설정하면 바로 정상 동작" → Phase A (web 1줄 env) + Phase E (server 2줄 env) 박제
2. **PAYMENT_BACKLOG_AUDIT §7 정합?** ✅ — "Polar KYC" + "EMAIL SaaS" 양측 게이트 사전 박제 = AUDIT 권장 진행 순서 정본
3. **PLANNING §0 마진 ≥3배 정합?** ✅ — Phase B+C+D는 새 AI 기능 추가 0건 (인증/알림은 비AI). cost-accountant 검증 불요 (단, G-Email-2 SaaS 단가는 §0 영향 — 별 sprint)
4. **사용자 절대 규정 0-1 정합?** ✅ — Phase B NullAdapter default + 외부 SDK import 0건 + dynamic import 패턴 + package.json 미박제
5. **결제 트랜잭션 원자성 정합?** ✅ — Phase D R4 위험 완화책 + AC-D2 spec + sensor-payment-idempotency 회귀 검증
6. **GCP 절대 규칙 정합?** ✅ — Phase E `grimoire-491708` + `asia-northeast1` 단일 + Secret Manager + Cloud Run env reference 정합
7. **마이그레이션 ≤2건 정합?** ✅ — Phase C C2 1건만
8. **shared-contracts 갱신 정합?** ✅ — Phase B B9 + Phase C C11 + Phase D D8 박제

---

## 20. orchestration 위임 핸드오프 (다음 agent 입력)

| agent | 입력 | 위임 단위 | 마감 |
|---|---|---|---|
| **grimoire-web** | 본 plan-draft §5 (Phase A 전체) | A1~A5 web sub-task | 게이트 #1 승인 후 즉시 |
| **grimoire-server** | 본 plan-draft §6+§7+§8 (Phase B+C+D 전체) | B1~B9 + C1~C11 + D1~D8 server sub-task | 게이트 #1 승인 후 즉시, Phase 게이트 단계 진척 |
| **grimoire-infrastructure** | 본 plan-draft §9 (Phase E 전체) | E1~E5 인프라 sub-task | Phase B+D 완료 후 |
| **grimoire-qa** | 본 plan-draft §11 (AC) + §10 (위험) + §17 (제약) | shared-contracts 갱신 검증 + sensor 회귀 + jest/vitest PASS | 모든 Phase 완료 후 |

**Phase 게이트 단계 진척**:
- Phase A 완료 → web `dev` 배포 + 24h 박제
- Phase B 완료 → factory DI 부팅 검증
- Phase C 완료 → migration apply + e2e PASS
- Phase D 완료 → sensor 회귀 0 검증
- Phase E 완료 → Cloud Run env reference 확인
- 마무리 → server+web `dev` 통합 배포 + 24h 박제 → `prod` 통합 배포

---

## 21. 본 plan-draft가 정의하지 않은 것 (OUT OF SCOPE)

| # | OUT | 사유 |
|---|---|---|
| 1 | ResendEmailAdapter / SesEmailAdapter 실 구현 | G-Email-5 별 sprint (사용자 G-Email-1+2 통과 후) |
| 2 | KakaoBizmessageAdapter / NhnCloudSmsAdapter 실 구현 | G-SMS-5 별 sprint (사용자 G-SMS-1+2 통과 후) |
| 3 | PAY-S6 Sentry 정식안 (운영 알림) | cost-accountant 게이트 + 별 sprint |
| 4 | PAY-S5 webhook 비동기화 | 현 트래픽 규모상 후순위 |
| 5 | 이메일 템플릿 디자인 (HTML/text) | Phase B B8 stub만 박제, 실 디자인은 별 sprint (디자이너 협업) |
| 6 | A/B 테스트 — Email vs SMS 전송 우선순위 | 사용자 사용 데이터 축적 후 |
| 7 | 이메일 unsubscribe 기능 | 마케팅 이메일 도입 시 별 sprint |
| 8 | OAuth 우선 정책 — `feedback_auth_decisions.md` 정합 | EMAIL-P1-1는 비밀번호 가입자에 한정 (OAuth는 자동 verified=true) |

---

**본 plan-draft 작성 완료** — 사용자 게이트 #1 승인 후 §20 orchestration 핸드오프 진행. 구현 진입 전 본 plan-draft 사용자 승인 필수.
