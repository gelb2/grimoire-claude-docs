# PAYMENT BACKLOG AUDIT — 2026-05-23

> 사용자 질문(verbatim): "polay kyc, payout, email sass 바로 고민하고 진행하면 되는지 아니면은 그 전에 짚고 넘어가야 할 다른 과제가 있는지 전수검사 해봐"
>
> 진단 전용 — 코드/문서 변경 0건. 모든 결론에 grep / Read / curl / sensor 실측 근거 동봉.

---

## 0. 핵심 결론 (TL;DR)

| 사용자 질문 | 답 | 핵심 이유 |
|---|---|---|
| **A. Polar KYC + payout** 즉시 진행해도 되나? | ✅ **즉시 진행 가능** (사용자 액션) | server/web 코드 게이트 0건. CC-5 web 페이지가 `setComingSoonOpen` 1줄을 `api.checkoutSubscription`으로 교체하면 즉시 실연결. Polar org 자체에 test mode 차단만 풀리면 라이브 결제 즉시. |
| **B. Email SaaS (PAY-P1-2)** 즉시 진행 가능? | ⚠️ **조건부 — 외부 게이트 3건 동시 통과 후** | (1) 사용자 절대 규정 0-1 (외부 API 신규 의존 보류) 명시 해제 / (2) cost-accountant SaaS 단가 검증(Resend/SendGrid) / (3) EMAIL-P1-1 인증 시스템 진입. 각 게이트는 독립 — 셋 다 통과 전 코드 진입 금지. |
| **C. PAY 백로그 Tier 1/2/3 분류** | 아래 §3 참조 | 사용자 액션(KYC) vs 자율 진행(S2/S3 배포·S5/S7) vs 게이트 차단(P1-2/S6 Sentry)으로 3등분. |

**가장 중요한 위험 1건** — 🟡 **PAY-S3 미배포** (server `17ac9d1` / web `d6f50e5` develop 푸시됨, dev/prod 배포 미실시). 배포 게이트 = 사용자 단독 결정. 마이그레이션 0건이므로 저위험 즉시 배포 가능.

**사용자 결정 게이트 Top 3**:
1. **Polar KYC + 한국 payout 승인 절차 착수** (가장 큰 차단막 — 5/22 박제 verbatim "구독 페이지 준비중 모드")
2. **PAY-S3 dev/prod 배포 승인** (저위험·즉시 가능, 단지 미실시 상태)
3. **절대 규정 0-1 해제 + Email SaaS 선택** (PAY-P1-2 / EMAIL-P1-1 모두 차단)

---

## 1. 현 상태 매트릭스 — 결제 sprint 전수

> 출처: `memory/project_remaining_tasks.md` "정밀진단 재추산 (2026-05-19)" + 5/21·5/22·5/23 갱신 노트, `reports/PAYMENT_PIPELINE_DIAGNOSIS.md` 표, shared-contracts §13~§30 변경 이력 14건.

### 1-1. 완료 (코드+테스트+배포 종결)

| Sprint | 상태 | 증거 |
|---|---|---|
| PAY-P0-1 webhook event_id 멱등성 | ✅ | shared-contracts §11 / sensor-payment-idempotency 7/7 PASS |
| PAY-P0-2 PG↔DB 정합 cron | ✅ | shared-contracts §12 / sensor-payment-reconciliation 10/10 PASS |
| PAY-P0-3 운영자 수동 지급 UI | ✅ | web `af3f04c` |
| PAY-P1-1 환불 atomicity | ✅ | shared-contracts §13 / sensor-refund-atomicity 10/10 PASS |
| PAY-P1-3 retry 정책 24h | ✅ | shared-contracts §14 |
| PAY-P1-4 Polar 구독 (= CC-5) | ✅ | server `d912a39` main + prod rev 107 (5/22). web 페이지 "준비중 모드"(`setComingSoonOpen`) — Polar KYC 통과 시 1줄 교체 즉시 실연결 |
| PAY-P2-1 부분 환불 비율 | ✅ | shared-contracts §17 |
| PAY-P2-2 webhook DLQ (Postgres) | ✅ | shared-contracts §18 |
| PAY-P2-3 사전 작업 (SmsServicePort 캡슐화) | ✅ | shared-contracts §19 — NullSmsAdapter default, **외부 SDK import 0건** |
| PAY-P2-4 AdminAuditLog before/after | ✅ | shared-contracts §20 |
| PAY-P2-5 audit retention | ✅ | shared-contracts §26 (dev+prod migration 적용) |
| PAY-P3-A race condition 차단 | ✅ | shared-contracts §22 (CC-2b 재작성 시 `$executeRawUnsafe` CAS로 이식 — `prisma-payment.repository.ts:334-352` 박제) |
| PAY-P3-B Polar SDK timeout | ✅ | shared-contracts §24 |
| PAY-P3-C retry dedup | ✅ | shared-contracts §23 |
| PAY-P3-D status enum mapping | ✅ | shared-contracts §28 |
| PAY-P3-E FK Cascade (33 FK + prod migration) | ✅ | shared-contracts §25 (5/15 prod apply) |
| PAY-P3-H Circuit Breaker | ✅ | shared-contracts §27 |
| **PAY-S1** 로컬 DB sync (5건 미적용) | ✅ | 5/20 |
| **PAY-S2** 다중 부분환불 누적 한도 (HIGH-1) | ✅ | shared-contracts §17 변경이력 / server `507c3b9` main / dev rev 166 + **prod rev 108 배포 완료** (5/22) |
| CC-1~CC-5 크레딧 개편 코어 | ✅ | shared-contracts §30 / Author.credits DROP + CreditLog 폐기 / prod rev 105 (5/21) → 107 (5/22) |
| USER-SOFT-DELETE | ✅ | shared-contracts §29 |
| EmailServicePort 캡슐화 | ✅ | server `b49b6ba` — NullEmailAdapter default |

### 1-2. 진행중 — 푸시 완료, 배포 대기

| Sprint | 상태 | 사용자 결정 필요 항목 |
|---|---|---|
| **PAY-S3** Circuit Breaker 운영자 admin UI | 🟡 **코드 종결, 미배포** | dev/prod 배포 승인 (저위험 — 마이그레이션 0건, env 신설 0건). server `17ac9d1` / web `d6f50e5` develop, `make deploy-dev` + `make deploy-prod` 실행만 남음. 5/23 박제. |

### 1-3. 잔존 — Tier 분류 대기

| Sprint | 정의 출처 | 분류 | 차단 사유 |
|---|---|---|---|
| **PAY-S4** 결제 알림 (Email+SMS) | `PAYMENT_PIPELINE_DIAGNOSIS.md` (구 PAY-P1-2) | 🔴 차단 | 절대 규정 0-1 + cost-accountant + EMAIL-P1-1 인증 — 게이트 3건 |
| **PAY-S5** webhook 비동기화 | `PAYMENT_PIPELINE_DIAGNOSIS.md:271` (MEDIUM-1) | 🟢 자율 가능 | 의존 0 — 단, 현 트래픽 수용 가능 = 후순위 |
| **PAY-S6** 운영 알림 (Sentry 정식안 / S3 admin UI 결합 최소안) | `PAYMENT_PIPELINE_DIAGNOSIS.md:272` (MEDIUM-3) | 🟡 부분 차단 | 최소안(S3에 흡수)은 ~+1h / Sentry 정식안은 cost-accountant 게이트 |
| **PAY-S7** cron 시간대 (payment-cleanup timeZone 명시) | `PAYMENT_PIPELINE_DIAGNOSIS.md:273` (LOW-1) | 🟢 자율 가능 | ~10분, S2/S3에 흡수 권장이었으나 S3에 미흡수 — 별도 micro-sprint |
| **Polar KYC + 한국 payout 승인** | `memory/reference_polar_setup.md` | 🔵 사용자 액션 | Polar test mode → live 전환 = Polar Dashboard에서 KYC 제출 + payout 등록 후 Polar support 승인 대기 |
| **EMAIL-P1-1** 인증 시스템 | `memory/project_remaining_tasks.md` EMAIL 영역 | 🔴 차단 | SaaS 선택은 미차단(dev NullEmailAdapter로 진입 가능). 실 발송은 SaaS 선택 후 |

---

## 2. 선행 과제 식별 — KYC/payout/Email SaaS 진행 전 짚어야 할 것

### 2-1. Polar KYC + payout — 선행 과제 ❌ 없음

검토 결과:

| 체크 | 결과 | 증거 |
|---|---|---|
| server 코드 차단 게이트? | ❌ 없음 | `start-subscription.usecase.ts:53` graceful 503 — env 미설정 시 503만 반환, KYC 통과 후 env 박제하면 즉시 정상 |
| web 코드 차단 게이트? | ❌ 없음 | CC-5 (5/22 박제) "준비중 모드 노출"·`setComingSoonOpen` 1줄을 `api.checkoutSubscription`으로 교체하면 실연결 |
| Polar 4 신 product 등록 상태? | ✅ 완료 | 5/21 4 신 product 등록·env 갱신, 구 3종 archive |
| Polar 구독 product (Pro/Premium) 등록? | ✅ 완료 | 5/22 Pro $9.99 / Premium $19.99 등록, dev/prod env 갱신 |
| cost-accountant priceUsd §0 검증? | ✅ 완료 | 5/22 PASS — 멤버십 priceUsd 박제 commit `c614d20` |
| Polar webhook endpoint 3환경 정합? | ✅ 완료 | `reference_polar_setup.md` 박제 (dev/inhouse/prod 3 endpoint enabled) |
| Polar access token 유효기간? | ⚠️ **2027-04-09 만료** | `reference_polar_setup.md:117` — 약 11개월 후 갱신 필요(개별 리마인더 권장이나 KYC 진행과 무관) |

**결론**: Polar KYC·payout은 사용자가 Polar Dashboard에서 직접 제출 + 한국 payout 등록 + Polar support 승인을 받는 외부 절차다. 코드/운영 측 **선행 과제 0건**. 승인 후 server env(현재 비어있을 가능성 있음) 박제만 하면 즉시 라이브.

### 2-2. Email SaaS (PAY-S4 / EMAIL-P1-1) — 선행 게이트 3건 (모두 외부)

`memory/project_remaining_tasks.md` "EMAIL 영역" + `shared-contracts.md` §19 (SmsServicePort) 패턴 박제 정합:

| 게이트 | 현재 상태 | 해소 조건 |
|---|---|---|
| **G1. 사용자 절대 규정 0-1 해제** | 🔴 미해제 | 사용자가 "외부 API 신규 의존 진입한다" 명시 |
| **G2. cost-accountant SaaS 단가 검증** | 🔴 미진행 | Resend(₩0~) / SendGrid(₩무료 100/일) / Postmark 비교 → cost-accountant 위임 → §0 PASS |
| **G3. EMAIL-P1-1 인증 시스템 진입** | 🔴 미진입 | SaaS 결정 X dev NullEmailAdapter로 진입 가능 — **사용자 5/10 명시**: "이메일은 인터페이스 구현 해놓으면 되잖아" (이미 EmailServicePort 캡슐화 완료 `b49b6ba`) |

**결론**: SaaS 결정과 인증 시스템 진입은 **독립적**이다 — EMAIL-P1-1은 NullEmailAdapter로 진입해도 인증 토큰 발행 + 검증 로직 자체는 구현 가능(dev 로그로 확인). 실 발송 시점에서 SaaS 어댑터(ResendEmailAdapter 등) 교체. 단 **PAY-S4 결제 알림은 실 발송 의미가 핵심**이므로 G1+G2 통과 전 진입 금지.

**선행 과제 Top 3** (SaaS 진입 전):
1. **사용자가 G1(절대 규정 0-1) 명시 해제** — 한 줄 발화 결정
2. **cost-accountant Email SaaS 단가 비교 위임** (Resend 무료 100/일 / SendGrid 무료 100/일 / Postmark ₩발송당) — 월 운영 비용 + §0 마진
3. **EMAIL-P1-1 인증 시스템 사양 결정** — 인증 토큰 형식 / 만료 / OAuth와의 동거 정책 (memory `feedback_auth_decisions.md` 정합)

---

## 3. 권장 우선순위 — Tier 1 / 2 / 3

### 🟢 Tier 1 — 즉시 (자율 진행 가능, 외부 의존 0)

| 순번 | 항목 | 규모 | 효과 |
|---|---|---|---|
| 1 | **PAY-S3 dev/prod 배포** | ~30분 | Circuit Breaker admin UI 운영 즉시 가용화. 마이그레이션 0건 + env 신설 0건 = 저위험 |
| 2 | **PAY-S7 cron 시간대 명시** | ~10분 | payment-cleanup cron `timeZone: 'Asia/Seoul'` 명시. LOW 결함이나 운영자 디버깅 편의 |
| 3 | **PAY-S5 webhook 비동기화** | ~3~4h | Polar webhook 200 즉시 응답 + 처리 큐 분리. **현 트래픽 규모상 후순위** — Tier 1 中 가장 낮음 |

### 🔵 Tier 2 — 선행 후 (사용자 단발 결정 필요)

| 순번 | 항목 | 선행 조건 | 효과 |
|---|---|---|---|
| 4 | **Polar KYC + 한국 payout 승인 절차 착수** | 사용자가 Polar Dashboard 직접 제출 | live 결제 즉시 가능 + 구독 페이지 1줄 교체로 CC-5 실연결 |
| 5 | **PAY-S6 운영 알림 (최소안)** | PAY-S3 배포 후 admin UI 결합 | permanent_failed / mismatch / circuit OPEN을 admin UI 배지 + AccessLogsTab 알림으로 노출. ~+1h |
| 6 | **EMAIL-P1-1 인증 시스템 + dev NullAdapter 진입** | SaaS 결정 X(NullAdapter로 진입) | 회원가입/비밀번호 재설정 인증 토큰 발행/검증 도메인 로직 + dev 로그 확인 — 실 발송은 SaaS 후속 |

### 🔴 Tier 3 — 외부 게이트 (사용자 결정 + 외부 검증 필요)

| 순번 | 항목 | 차단 게이트 | 해소 절차 |
|---|---|---|---|
| 7 | **PAY-S4 결제 알림 (Email+SMS)** | G1 절대 규정 0-1 + G2 cost-accountant + G3 EMAIL-P1-1 | 게이트 3건 통과 후 ResendEmailAdapter + Kakao Bizmessage SmsAdapter 추가 |
| 8 | **PAY-S6 운영 알림 (Sentry 정식안)** | cost-accountant | Sentry $26/월(Team 플랜) 또는 self-host 결정 + 마진 영향 검증 후 |
| 9 | **Email SaaS 어댑터 추가** | G1+G2 | ResendEmailAdapter 어댑터 1건 추가 + env 박제 + spec 5건. UseCase 코드 변경 0건(EmailServicePort 인터페이스 정합) |

---

## 4. 위험 매트릭스 — 잔여 sprint별

| 항목 | 위험도 | 완화책 |
|---|---|---|
| PAY-S3 미배포 | 🟡 운영 가시성 부족 | dev 우선 배포 → 24h 박제 → prod 배포 (저위험) |
| Polar test mode 잔존 | 🟡 사용자 결제 시도 시 "Payments are currently unavailable" 노출 | (a) 사용자 KYC 제출 가속 또는 (b) 구독 페이지에 "곧 오픈" 안내 노출 (이미 CC-5 web "준비중 모드" 박제됨) |
| PAY-S4 미진입 (결제 알림 0) | 🟡 사용자 결제 실패 후 재시도 안내 부재 | 단기 — toast.error만 활용 / 장기 — G1+G2+G3 통과 후 SaaS 진입 |
| PAY-S6 운영 알림 0 | 🟡 permanent_failed / mismatch / circuit OPEN 운영자 자각 지연 | 단기 — PAY-S3 admin UI 결합 최소안 +1h / 장기 — Sentry 정식안 (cost-accountant 게이트) |
| Polar webhook auto-disable | 🟢 Polar가 전송 실패 반복 시 자동 disable | `reference_polar_setup.md:44` 박제 — 배포 전후 `GET /v1/webhooks/endpoints/{id}` enabled 확인 패턴 (현재 3환경 정합) |
| Polar access token 만료 (2027-04-09) | 🟢 약 11개월 후 | 별도 캘린더 리마인더 — 본 sprint 진행과 무관 |
| Polar 쿠폰 운영 차단 | 🟢 dev/prod 환경 분리 불가 | `feedback_polar_coupon_ops.md` 박제 — 긴 랜덤 코드 정책 정합 (현재 정상) |
| **sensor-payment-race-condition FAIL 2건** | 🟢 **false-positive 확정** | sensor regex가 구 `findUniqueOrThrow` 패턴을 검사하나, CC-2b 재작성으로 `$executeRawUnsafe` CAS 패턴으로 이행됨(`prisma-payment.repository.ts:334-352`). sensor 자체 업데이트 필요 (별도 micro-sprint) — 본 audit 범위 외 |
| sensor-credit-atomicity WARN 2건 | 🟢 stale | `$transaction` payment 5건 / credit 0건 — CC-4 Phase 3 이후 CreditLog 폐기로 creditLog.create 0건이 정상(WARN regex 미반영). sensor regex 업데이트 필요 |
| sensor-cost-margin WARN 6건 (안전배수 3.0~3.5×) | 🟡 조기 경보 | `ai-cost-table.md` 최소 3.00× — Sonnet +20% 또는 환율 +8.5% 시 §0 위반 진입 가능. cost-accountant 정기 모니터링 (절대 위반 아님) |
| sensor-eval-trend FAIL (회귀) | 🟡 eval 7일 mean=0.9714 < 30일 0.9831 | EDD stale 16일은 외부 Anthropic API 보류 사유. regression mean 회귀는 별도 sprint (본 audit 범위 외) |
| DB Sync Nightly 6일 연속 실패 | 🟢 진행 무관 | `gh run view 26301447172 --log-failed` — `grimoireadmin` DB credentials 만료. 본 audit는 결제 영역 — DB Sync는 별도 infrastructure 영역 (grimoire-infrastructure agent 영역) |

---

## 5. 사용자 결정 게이트 — 진행 전 결정 필요 항목

### 🔵 게이트 #1. PAY-S3 dev/prod 배포 승인 (Tier 1)

- **결정 내용**: `make deploy-dev` + `make deploy-prod` 실행
- **저위험 근거**: 마이그레이션 0건 + env 신설 0건 + 새 admin 탭 0건 + 새 시각 정본 0건
- **소요**: ~30분
- **권장**: dev 우선 → 24h 박제 → prod (또는 5/22 PAY-S2 패턴 메인 직접 배포 적용)

### 🔵 게이트 #2. Polar KYC + 한국 payout 승인 절차 착수 (Tier 2)

- **결정 내용**: Polar Dashboard `Settings → Account` 진입 → KYC 제출 + 한국 payout 등록 + Polar support 승인 요청
- **소요**: Polar support 대기 (수일~수주)
- **server 측 코드/문서 변경 0건** — 사용자 단독 액션
- **승인 후**: server env(`POLAR_PRODUCT_SUBSCRIPTION_*` 등 미설정 시 추가) + web `setComingSoonOpen` → `api.checkoutSubscription` 1줄 교체

### 🔵 게이트 #3. 절대 규정 0-1 해제 (Tier 3 진입 조건)

- **결정 내용**: "외부 API 신규 의존(Email SaaS) 진입 한다" 사용자 명시
- **`memory/project_remaining_tasks.md`** 박제 사항 — 4/30 박제 "외부 api를 쓰는 방향으로의 하네스엔지니어링, 에이전트 고도화는 나중 과제로 좀 미루고 싶다"
- **해제 후**: cost-accountant Email SaaS 단가 비교 위임 → ResendEmailAdapter / SendGrid / Postmark 中 선택 → SaaS 어댑터 1건 추가

---

## 6. 결제 도메인 코드 TODO·FIXME·incomplete 검사

`grep -rn "TODO|FIXME|XXX|HACK|stub|미구현|미연동" grimoire-server/src/application/{payment,credit,subscription}` 결과:

| 매치 | 분류 | 박제 정합 |
|---|---|---|
| `payment.usecase.ts:99` "classifyPolarError 미구현 시 'unknown' fallback (회귀 보존)" | (a) 의도된 fallback | PolarSDKTimeoutPolicy §24 정합 — paymentGateway 인터페이스 Optional 메서드 |
| `payment.usecase.spec.ts:974,982` AC-5 fallback case | (a) 의도된 spec | 위와 동일 |
| `payment-charge-credit-integration.spec.ts:8,19,306,330` "적립 미연동 재현" | (a) RED 재현 spec | CC-2a 통합 spec — CRITICAL-2 회귀 차단 박제 |
| `credit-grant-integration.spec.ts:7,8,18,367` "적립 5경로 미연동" | (a) RED 재현 spec | CC-1 통합 spec |
| `credit-grant-integration.spec.ts:45` "google-auth-library Mock 미사용 stub" | (c) 의도된 stub | OAuth 회귀 보호용 |
| `credit-grant-integration.spec.ts:308,316` "부수 포트 stub" | (c) 의도된 stub | |
| `credit-gift-refund-integration.spec.ts:18,344,352,701` "환불 미연동 재현" | (a) RED 재현 spec | CC-2b 통합 spec |
| `start-subscription.usecase.ts:53` "graceful §4 — adapter가 initiateSubscriptionCheckout 미구현 시 503" | (c) 의도된 stub | CC-5 graceful — env 미설정 시 503, Polar KYC 통과 후 env 박제하면 자동 정상화 |

**판정**: 잔존 결함 0건 — 모두 (a) RED 재현 spec / (c) 의도된 fallback/stub.

---

## 부록 A. sensor 실측 raw (5/23 11:00 KST)

```
sensor-deploy-health grimoire-server-prod:
  revision: 0000108 (Healthy / ScaledToZero / traffic=100%)
  HealthState=Healthy, Traffic=100%, curl api.grimoire-book.com/api/payments/products HTTP 200 (23s)
  WARN — ScaledToZero (idle 정상, 첫 트래픽 시 cold start)

sensor-deploy-health grimoire-web-prod:
  revision: 0000120 (Healthy / Activating / traffic=100%)
  HealthState=Healthy, Traffic=100%, curl HTTP 307 (18s)
  WARN — Activating (시작 중, 30~60s 대기)

sensor-payment-idempotency: PASS 7/7
sensor-payment-reconciliation: PASS 10/10
sensor-refund-atomicity: PASS 10/10
sensor-circuit-breaker-policy: PASS 10/10
sensor-payment-race-condition: PASS 6 / FAIL 2  ← false-positive (sensor regex stale, CC-2b 이후 CAS 패턴 이행)
  - [FAIL] prisma-payment.repository: findUniqueOrThrow 누락 — race 진입 부재
  - [FAIL] prisma-payment.repository: CAS 패턴 누락 — race window 회귀
  실측: prisma-payment.repository.ts:334-352에 $executeRawUnsafe CAS 박제 완료. sensor 자체 업데이트 필요.

sensor-credit-atomicity:
  WARN — $transaction payment 5건 / credit 0건 — 한쪽만 보장됨
  WARN — creditLog.create 호출 0건 — audit trail 부재 가능성
  실측: CC-4 Phase 3 (5/21) CreditLog 폐기 + Author.credits DROP 완료. CreditLedger가 정본. sensor regex stale.

sensor-cost-margin:
  WARN — 안전배수 6건 3.0~3.5× (FAIL 0건). 최소 3.00× / 평균 3.39× / 최대 3.97×.
  ai-cost-table.md 최종 갱신 2026-05-16 (7일 전, stale=false).

sensor-eval-trend:
  WARN regression — 30일 mean=0.9831 / 7일 mean=0.9714 / 최근10 FAIL=10
  FAIL edd — stale 16일 (외부 Anthropic API 보류 사유, 의도된 정합)
```

## 부록 B. gh run list 발췌 (최근 30회)

```
완료 success: PAY-S3 docs(pay-s3)  develop  push  2026-05-23T01:30:59Z
완료 failure: DB Sync (Nightly)  main  schedule  2026-05-22T17:07:57Z  ← 6일 연속 실패 (grimoireadmin DB credentials)
완료 success: merge: develop→main (프로모션) 2026-05-22T14:23:27Z
완료 success: merge: PAY-S2 다중 부분환불 누적 한도 검증 (HIGH-1 해소) 2026-05-22T14:01:27Z
완료 success: merge: develop→main (CC-5 Polar 구독 정기결제 + HIGH-1 案 B) 2026-05-22T08:57:08Z
완료 success: docs(cost): CC-5 멤버십 priceUsd §0 검증 박제 ($9.99/$19.99 PASS) 2026-05-22T08:55:22Z
완료 failure: DB Sync (Nightly) 2026-05-21T17:30:23Z
완료 success: merge: develop→main (CC-4 Phase 3 Author.credits DROP) 2026-05-21T13:01:53Z
(중략 — CC-4 Phase 1/2/3 + CC-1~3 + USER-SOFT-DELETE 모두 success)
완료 failure: DB Sync (Nightly) 5건 (5/16~5/22 매일)
```

**판정**: CI workflow 본체는 30회 中 24회 success / 6회 failure. failure 6건 전부 `DB Sync (Nightly)` 스케줄 — grimoireadmin DB credentials 만료 (`reports/PAYMENT_PIPELINE_DIAGNOSIS.md` 외부 영역). 결제 영역 CI workflow 회귀 0건.

## 부록 C. shared-contracts 결제 §11~§30 잔존 영역 박제 매트릭스

| § | 영역 | 잔존 | 상태 |
|---|---|---|---|
| §11 WebhookEventIdempotency | — | 0건 | PAY-P0-1 완료 |
| §12 PaymentReconciliation | replicas≥2 시 advisory_lock 보강 | P1 보류 | 단일 인스턴스 가정 |
| §13 RefundPaymentAtomically | CC-4 Phase 4 응답 일관성 | P2 별도 sprint | `processNormalizedWebhook` 반환 키 정합 (외부 호환성 영향 평가 종속) |
| §14 PaymentRetryReuse | — | 0건 | PAY-P1-3 완료 |
| §15 SlugLogin | — | 0건 | EMAIL-P0-3 영역 |
| §16 OAuthEmailVerification | — | 0건 | |
| §17 PartialRefund | 다중 부분환불 정식 지원 (Polar webhook 다중 송신 동작 확인 + reconciliation 정합) | PAY-P2 확장 별도 sprint | 案 A 정합 — 현재 webhook 게이트로 2회차 차단 |
| §18 WebhookDLQ | replicas≥2 advisory_lock 강화 | P1 보류 | |
| §19 SmsServicePort | provider 결정 후 SDK adapter 추가 | 사용자 결정 후 (G1+G2) | NullSmsAdapter default — 외부 SDK import 0건 |
| §20 AdminAuditLog before/after | — | 0건 | PAY-P2-4 완료 |
| §21 InfraMutationGuard | — | 0건 | infrastructure 영역 |
| §22 PaymentRaceCondition | replicas≥2 advisory_lock + partial unique index | P2 보류 | sensor stale (CC-2b 이후 CAS 패턴 이행 미반영) |
| §23 RetryDeduplication | failed/expired status retry 정책 결정 | 별도 sprint | |
| §24 PolarSDKTimeoutPolicy | — | 0건 | PAY-P3-B 완료 |
| §25 FKCascadePolicy | — | 0건 | PAY-P3-E 완료 (33 FK + prod migration 5/15) |
| §26 AuditRetentionPolicy | — | 0건 | PAY-P2-5 완료 (dev+prod migration 적용) |
| §27 CircuitBreakerPolicy | 다중 인스턴스 in-memory 분리(Redis) / 정책 변경 시 재시작 / **관리자 UI ✅ PAY-S3 종료 (5/23)** / 호출 빈도 인벤토리 모니터링 | 잔존 3건 | PAY-S3 항목 strike (5/23) |
| §28 PaymentStatusMapping | — | 0건 | PAY-P3-D 완료 |
| §29 UserSoftDeletePolicy | — | 0건 | USER-SOFT-DELETE 완료 |
| §30 CreditOverhaul | `Author.plan`/`planExpireAt` 컬럼 물리 DROP (HIGH-1 案 B 후속) / `MembershipPlanPort.getPlan` HTTP 노출 | 별도 sprint | CC-5 案 B 종결, 미러 컬럼만 잔존 |

## 부록 D. 결제 webhook 처리 이벤트 화이트리스트

`polar.adapter.ts:390-449` switch 박제:

```
case 'order.paid' / 'order.updated' → 충전 success
case 'order.refunded' → 환불 cancel
case 'checkout.updated' → status='succeeded'/'failed'/'expired' 폴백
case 'subscription.created' / 'updated' / 'canceled' / 'revoked' → CC-5 구독 4 이벤트
default → return null (그 외 이벤트 무시 — benefit.* / customer.* 등 미지원)
```

**판정**: 화이트리스트 정합. 비-화이트리스트 이벤트는 null 반환 → payment.usecase가 200 OK 응답하되 처리 0건 (PAY-P0-1 멱등성 영역).

## 부록 E. 결제 실패 / 환불 UX (web)

`grimoire-web/src/app/dashboard/credits/page.tsx`:

| 시나리오 | UX |
|---|---|
| 결제 성공 | URL `checkout_id` 감지 → `toast.success('결제가 완료되었습니다. 포인트가 곧 반영됩니다.')` |
| 결제 시작 실패 | `toast.error('결제를 시작할 수 없습니다. 잠시 후 다시 시도해주세요.')` |
| 결제 실패 webhook 후 알림 | ❌ **없음** — Email/SMS 알림 미진입 |
| 환불 완료 알림 | ❌ **없음** — Email/SMS 알림 미진입 |
| 구독 갱신 실패 알림 | ❌ **없음** |

**판정**: 결제 진입 시점 UX는 정합. **사후 알림은 PAY-S4 (Tier 3 차단) 진입 후 해소**.

---

## 7. 최종 권장 진행 순서

```
[즉시 가능 — 사용자 결정 1건]
  → PAY-S3 dev/prod 배포 승인 (~30분, 저위험)
  → PAY-S7 cron 시간대 (~10분, micro)

[병렬 — 사용자 외부 액션 1건]
  → Polar KYC + payout 승인 절차 착수 (Polar Dashboard, 수일~수주 대기)
     ↓ (Polar 승인 완료 시점에)
  → web CC-5 페이지 1줄 교체 (setComingSoonOpen → api.checkoutSubscription)
  → 구독 결제 라이브 즉시

[후순위 — 트래픽 규모 따라 결정]
  → PAY-S5 webhook 비동기화 (~3~4h)
  → PAY-S6 운영 알림 최소안 (PAY-S3 admin UI 결합, ~+1h)

[게이트 후 진행 — 사용자 결정 + cost-accountant]
  → 절대 규정 0-1 해제 명시
  → cost-accountant Email SaaS 단가 비교 위임
  → EMAIL-P1-1 인증 시스템 진입 (dev NullEmailAdapter — SaaS 결정 X)
  → SaaS 결정 시 → ResendEmailAdapter 추가
  → PAY-S4 결제 알림 + EMAIL-P1-1 실 발송 활성
  → PAY-S6 Sentry 정식안 (별도)
```
